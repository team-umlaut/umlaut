# Service that searches MBooks from the University of Michigan
# Currently limited since it only searches by OCLCnum
#
# Supports full text links, and search inside. 
#
# Most MBooks will also be in Google Books (but not neccesarily vice versa).
# However, U of M was more generous in deciding what books are public domain.
# Therefore the main expected use case is to use with Google Books, with
# MBooks being a lower priority, using preempted_by config.  
#
# Some may prefer MBooks search inside interface to Google, so search inside
# is not suppressed with presence of google. You can turn off MBooks
# search inside entirely if you like. 
# 
# Two possibilities are available for sdr rights "full" or "searchonly".
# The third possibility is that sdr will be null.
#
# An ISBN with search-only: 0195101464


class MBooks < Service
  require 'open-uri'
  require 'json'
  include MetadataHelper
  
  attr_reader :url, :display_name, :note
  
  def service_types_generated
    types = [ ServiceTypeValue[:fulltext] ]
    types << ServiceTypeValue[:search_inside] if @show_search_inside

    return types
  end
  
  def initialize(config)
    @url = 'http://mirlyn-classic.lib.umich.edu/cgi-bin/sdrsmd?'
    @hathi_search_url = 'https://babel.hathitrust.org/shcgi/ptsearch'
    # HT links are handle.net, but we can't really use Shib login with
    # handle.net, so we hard-code the particular host that the handle.net
    # resolves to, sorry! 
    @hathi_link_url = "https://babel.hathitrust.org/shcgi/pt"
    @display_name = 'HathiTrust'
    @num_full_views = 1
    @note =  '' #'Fulltext books from the University of Michigan'
    @show_search_inside = true
    super(config)
  end
  
  def handle(request)
    get_viewability(request)
    return request.dispatched(self, true)
  end
  
  def get_viewability(request)    
    params = get_parameters(request.referent)
    return nil if params.nil?
    mb_response = do_query(params)
    c_response = clean_response(mb_response)
    return nil if c_response.nil?
    
    # Only add fulltext if we're not skipping due to GBS
    if ( preempted_by(request, "fulltext"))
         RAILS_DEFAULT_LOGGER.debug("MBooks service: Skipping due to pre-emption")
    else
         full_views_shown = create_fulltext_service_response(request, c_response)
    end
    

    do_search_inside(request, c_response)
        
  end
  
  # just a wrapper around get_bibkey_parameters
  def get_parameters(rft)
    # API supports oclcnum, isbn, or lccn, and can provide more than one of each. 
    get_bibkey_parameters(rft) do |isbn, lccn, oclcnum|
      # Prefer ISBN, best chance of a hit. Else oclc, else lccn.   
      keys = Array.new
      
      keys << "isbn=" + CGI.escape(isbn) unless isbn.blank?      
      keys << "oclc=" + CGI.escape(oclcnum) unless oclcnum.blank?    
      keys <<  "lccn=" + CGI.escape(lccn) unless lccn.blank?

      if keys.length > 0
        return keys.join("&")
      else
        return nil
      end
    end
  end
  
  # method that takes a referent and a block for parameter creation
  # The block receives isbn, lccn, oclcnum and is responsible for formatting
  # the parameters for the particular service
  # FIXME consider moving this into metadata_helper
  def get_bibkey_parameters(rft)
    isbn = get_identifier(:urn, "isbn", rft)
    oclcnum = get_identifier(:info, "oclcnum", rft)
    lccn = get_lccn(rft)
        
    yield(isbn, lccn, oclcnum)    
  end
  
  # conducts query and parses the JSON
  def do_query(params)
    link = @url + params
    return JSON.parse( open(link).read )
  end
  
  # We're only interested in the 'sdr's and only those that have some rights
  def clean_response(resp)
    cleaned_response = []
    # because of the structure of the response we recurse through it to get
    # what we're after. OK, this is a bit of premature optimization since we
    # only have one response returned right now.
    resp['result'].each_value do |id_value|
      return nil if id_value.nil?
      id_value.each do |hit|
        cleaned_response << hit['sdr'] unless hit['sdr'].nil?
      end
    end
    cleaned_response
  end
  
  # FIXME abstract this out for use with both GBS and MBooks
  def create_fulltext_service_response(request, data)
    display_name = @display_name
    
    full_views = data.select{|d| d['rights'] == 'full'}
    return nil if full_views.empty?
    count = 0
    full_views.each do |fv|
      request.add_service_response(
        {:service=>self, 
          :display_text=>display_name, 
          :url=>@hathi_link_url + '?id=' + fv['handle'], 
          :notes=> @note}, 
        [ :fulltext ]) 
      count += 1
      break if count == @num_full_views
    end   
    return true
  end

  def do_search_inside(request, data)

    
    search_views = data.select{|d| d['rights'] == 'searchonly' || d['rights'] == 'full'}

    return if search_views.blank?
    
    search_view = search_views.first

    request.add_service_response( 
        {:service => self,
        :display_text=>@display_name,
        :url=> @hathi_search_url + '?id=' +  
          search_view["handle"]},
        [:search_inside]
       )
  end
  
  
  # Handle search_inside
  def response_url(service_type, submitted_params)
    if ( ! (service_type.service_type_value.name == "search_inside" ))
      return super(service_type, submitted_params)
    else
      base = service_type.service_response[:url]      
      query = CGI.escape(submitted_params["query"] || "")
      url = base + "&q1=#{query}"

      return url
    end
  end
  
  # sample OCLCnums with appropriate results showing that we can pick up other
  #   resources by using this service
  # 02029914  MBooks: full, GBS: info with search inside
  # 01635828  MBooks: full, GBS: snippet
  # 55517975  MBooks: search, GBS: limited preview
  # 02299399  MBooks: full, GBS: snippet
  # 16857172  MBooks: full, GBS: info
  
end
