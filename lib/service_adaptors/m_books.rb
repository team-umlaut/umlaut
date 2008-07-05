# Service that searches MBooks from the University of Michigan
# Currently limited since it only searches by OCLCnum 
# 
# Two possibilities are available for sdr rights "full" or "searchonly".
# The third possibility is that sdr will be null.
# 
# MBooks sometimes shows fulltext or search sometimes when GBS has lesser access
# FIXME Eventually this service will be able to offer search inside

class MBooks < Service
  require 'open-uri'
  require 'json'
  include MetadataHelper
  
  attr_reader :url, :display_name, :note
  
  # FIXME add search_inside later, which ought to be _very_ easy to do with MBooks
  def service_types_generated
    return[ 
      ServiceTypeValue[:fulltext],
      ServiceTypeValue[:highlighted_link]  ]
  end
  
  def initialize(config)
    @url = 'http://mirlyn.lib.umich.edu/cgi-bin/sdrsmd?'
    @display_name = 'MBooks'
    @num_full_views = 1
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
    # FIXME once we can search for more than one identifier at a time we'll
    #   need to dedupe our resultset
    full_views_shown = create_fulltext_service_response(request, c_response)
    
    unless full_views_shown
      do_web_links(request, c_response)
    end
    
  end
  
  # just a wrapper around get_bibkey_parameters
  def get_parameters(rft)
    # FIXME currently the API only supports oclcnum
    get_bibkey_parameters(rft) do |isbn, lccn, oclcnum|      
      return nil if oclcnum.nil?
      'oclc=' << oclcnum          
    end
  end
  
  # method that takes a referent and a block for parameter creation
  # The block receives isbn, lccn, oclcnum and is responsible for formatting
  # the parameters for the particular service
  # FIXME consider moving this into metadata_helper
  def get_bibkey_parameters(rft)
    isbn = get_identifier(:urn, "isbn", rft)
    oclcnum = get_identifier(:info, "oclcnum", rft)
    lccn = get_identifier(:info, "lccn", rft)
        
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
    note = @note || 'Fulltext books from the University of Michigan'
    full_views.each do |fv|
      request.add_service_response(
        {:service=>self, 
          :display_text=>display_name, 
          :url=>fv['mburl'], 
          :notes=>note}, 
        [ :fulltext ]) 
      count += 1
      break if count == @num_full_views
    end   
    return true
  end
  
  # other than full view MBooks only provides searchonly
  # FIXME until search inside is integrated into trunk create a link for this
  def do_web_links(request, data)
    search_views = data.select{|d| d['rights'] == 'searchonly'}
    return nil if search_views.blank?
    
    search_view = search_views.first
    url = search_view['mburl']
    display_text = "Search Inside"
    #notes = search_view['handle']
    request.add_service_response( { 
        :service=>self,    
        :url=>url,
        :display_text=>display_text,
        :service_data => {
          #:notes => notes
          }},
      [ServiceTypeValue[:highlighted_link]]    ) 
  end
  
  
  # sample OCLCnums with appropriate results showing that we can pick up other
  #   resources by using this service
  # 02029914  MBooks: full, GBS: info with search inside
  # 01635828  MBooks: full, GBS: snippet
  # 55517975  MBooks: search, GBS: limited preview
  # 02299399  MBooks: full, GBS: snippet
  # 16857172  MBooks: full, GBS: info
  
end