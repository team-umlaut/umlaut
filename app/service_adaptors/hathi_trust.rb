require 'open-uri'
require 'multi_json'
require 'cgi'

# Service that searches HathiTrust from the University of Michigan
#
# Supports full text links, and search inside. 
#
# We link to HathiTrust using a direct babel.hathitrust.org URL instead
# of the handle.net redirection, for two reasonsL
# 1) Can't use the handle.net redirection for the "direct link to search
#    results for user-entered query" feature. 
# 2) Some may want to force a Shibboleth login on HT links. Can't do that
#    with the handle.net redirection either. If you do want to do that,
#    possibly in concert with an EZProxy mediated WAYFless login,
#    set direct_link_base in your services.yml to:
#    "https://babel.hathitrust.org/shcgi/"
#
# Many (but not all) HT books will also be in Google Books (and vice versa)
# However, HT was more generous in deciding what books are public domain than GBS.
# Therefore the main expected use case is to use with Google Books, with
# HT being a lower priority, using preempted_by config.  
#
# Some may prefer HT search inside interface to Google, so search inside
# is not suppressed with presence of google. You can turn off HT
# search inside entirely if you like.
#
# For HT records representing one volume of several, a :excerpts type
# response will be added if full text is avail for some. Or a :highlighted_link
# if only search inside is available for some.
# Or set config show_multi_volume=false to prevent this and ignore partial
# volumes. 
# 
# Two possibilities are available for sdr rights "full" or "searchonly".
# The third possibility is that sdr will be null.
#
# An ISBN with search-only: 0195101464
class HathiTrust < Service  
  include MetadataHelper
  
  attr_reader :url, :display_name, :note
  
  def service_types_generated    
    types = [ ServiceTypeValue[:fulltext] ]
    types.concat([ServiceTypeValue[:excerpts], ServiceTypeValue[:highlighted_link]]) if @show_multi_volume
    types << ServiceTypeValue[:search_inside] if @show_search_inside
    return types
  end
  
  def initialize(config)
    @api_url = 'http://catalog.hathitrust.org/api/volumes'
    # Set to 'https://babel.hathitrust.org/shcgi/' to force
    # Shibboleth login, possibly in concert with EZProxy providing
    # WAYFLess login. 
    @direct_link_base = 'http://babel.hathitrust.org/cgi/'
    @display_name = 'HathiTrust'
    @num_full_views = 1 # max num full view links to include
    @note =  '' #'Fulltext books from the University of Michigan'
    @show_search_inside = true
    @show_multi_volume = true
    
    @credits = {
      "HathiTrust" => "http://www.hathitrust.org"
    }
    
    super(config)
  end
  
  def handle(request)
    params = get_parameters(request.referent)
    return request.dispatched(self, true) if params.blank?
    
    ht_json = do_query(params)
    return request.dispatched(self, true) if ht_json.nil?
    
    #extract the "items" list from the first result group from
    #response.
    first_group = ht_json.values.first    
    items = first_group["items"]
    
    
    
    # Only add fulltext if we're not skipping due to GBS
    if ( preempted_by(request, "fulltext"))
      Rails.logger.debug("#{self.class}: Skipping due to pre-emption")
    else
      full_views_shown = create_fulltext_service_response(request, items)
    end
    
    if @show_multi_volume
      #possibly partial volumes
      create_partial_volume_responses(request, ht_json)
    end

    

    create_search_inside(request, items)
        
    return request.dispatched(self, true)
  end
  
  # just a wrapper around get_bibkey_parameters
  def get_parameters(rft)
    # API supports oclcnum, isbn, or lccn, and can provide more than one of each. 
    get_bibkey_parameters(rft) do |isbn, lccn, oclcnum|         
      keys = Array.new
                  
      keys << "oclc:" + CGI.escape(oclcnum) unless oclcnum.blank?    
      keys <<  "lccn:" + CGI.escape(lccn) unless lccn.blank?
      # Only include ISBN if we have it and we do NOT have oclc or lccn,
      # Bill Dueber's advice for best matching. HT api will only match
      # if ALL the id's we supply match. 
      keys << "isbn:" + CGI.escape(isbn) unless (isbn.blank? || keys.length > 0)

      if keys.length > 0        
        return keys.join(";")
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
    # filter out special chars that ought not to be in there anyway,
    # and that HathiTrust barfs on. 
    isbn = get_isbn(rft)
    
    oclcnum = get_identifier(:info, "oclcnum", rft)
    oclcnum = oclcnum.gsub(/[\-\[\]]/, '') unless oclcnum.blank?
    
    lccn = get_lccn(rft)
    lccn = lccn.gsub(/[\-\[\]]/, '') unless lccn.blank?
        
    yield(isbn, lccn, oclcnum)    
  end
  
  # conducts query and parses the JSON
  def do_query(params)        
    link = @api_url + "/brief/json/" + params
    return MultiJson.load( open(link).read )
  end
  
    
  def create_fulltext_service_response(request, items)
    return nil if items.empty?
    
    count = 0
    
    items.each do |item|         
      next if is_serial_part?(item)
      
      
      next unless full_view?(item)
      
      request.add_service_response(
          :service=>self, 
          :display_text=> @display_name,
          :display_text_i18n => "display_name",
          :url=> direct_url_to(item), 
          :add_i18n_notes => "single_volume", # signal for transform_view_data
          :source_for_i18n => item['orig'],
          :service_type_value => :fulltext 
      )
      count += 1
      break if count == @num_full_views
    end   
    return count
  end
  
  
  # If HT has partial serial volumes, include a link to that. 
  # Need to pass in complete HT json response
  def create_partial_volume_responses(request, ht_json)
    items =  ht_json.values.first["items"]
    full_ids = items.collect do |i| 
      i["fromRecord"] if (is_serial_part?(i) && full_view?(i))
    end.compact.uniq
    
    full_ids.each do |recordId|
      record = ht_json.values.first["records"][recordId]
      next unless record && record["recordURL"]
    
      record_title = record["titles"].first if record["titles"].kind_of?(Array)
    
      request.add_service_response(
          :service=>self, 
          :display_text=> @display_name,
          :display_text_i18n => "display_name",
          :url=> record["recordURL"],
          :add_i18n_notes => "partial_volume", # signal for transform_view_data
          :title_for_i18n => record_title,
          :service_type_value => :excerpts
      )
    end
    
    if full_ids.empty?
      search_ids = items.collect do |i|
        i["fromRecord"] if (is_serial_part?(i) )
      end.compact.uniq
      
      search_ids.each do |recordId|
        record = ht_json.values.first["records"][recordId]
        next unless record && record["recordURL"]
        
        request.add_service_response(
            :service=>self, 
            :display_text=> "Search inside some volumes",
            :display_text_i18n => "search_inside_some_vols",
            :url=> record["recordURL"],
            :service_type_value => :highlighted_link             
        )   

      end
      
    end
    
    
  end
  
  def create_search_inside(request, items)
    return if items.empty?

    # Can only include search from the first one  
    # There's search inside for _any_ HT item. We think. 
    item = items.first
    
    # if this is a serial, we don't want to search inside just part of it, forget it
    return if is_serial_part?(item) 
    
    direct_url = search_url_to(item)
    return unless direct_url

    request.add_service_response( 
        :service => self,
        :display_text=> @display_name,
        :display_text_i18n => "display_name",
        :url=> direct_url,
        :service_type_value => :search_inside
       )
  end
  
  def direct_url_to(item_json)
    if @direct_link_base
      # we're constructing our own link because we need our EZProxy
      # to recognize it for WAYFLess login, which it won't if we use
      # the handle.net url, sorry. 
      # We also need direct link for direct link to search results.
      @direct_link_base + "pt?id=" + CGI.escape(item_json['htid'])
    else
      item['itemURL']
    end
  end

  def transform_view_data(hash)
    if hash[:add_i18n_notes] == "single_volume"
      hash[:notes] = translate("note_for_single_vol", :source => (hash[:source_for_i18n] || ""))
    elsif hash[:add_i18n_notes] == "partial_volume"
      hash[:notes] = translate("note_for_multi_vol", :title => (hash[:title_for_i18n] || ""))
    end

    return hash
  end
  
  
  def is_serial_part?(item)
    # if it's got enumCron, then it's just part of a serial,
    # we don't want to say the serial title as a whole has full text
    # or can be searched, skip it. 
    return item['enumcron']
  end
  
  def full_view?(item)
    item["usRightsString"] == "Full view"
  end
  
  def search_url_to(item_json)
    if @direct_link_base
      @direct_link_base + "ptsearch?id=" + CGI.escape(item_json['htid'])
    else
      return nil
    end
  end


  
  
  # Handle search_inside
  def response_url(service_response, submitted_params)
    if ( ! (service_response.service_type_value.name == "search_inside" ))
      return super(service_response, submitted_params)
    else
      base = service_response[:url]      
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
  
  # Example of a serial with some full text volumes:
  # JAMA, lccn:07037314
  #
  # Example of a multi-volume with search-only, split accross
  # two HT records. 
  # Handbook of biochemistry and molecular biology lccn: 75029514
  
end
