# search_zip_code param required. 
# Optional base_url param, but I don't know why you'd want to change it.
# display_text 
class Worldcat < Service
  required_config_params :search_zip_code
  
  def initialize(config)
    # defaults
    @base_url = 'http://www.worldcat.org/'
    @display_text = 'View at OCLC Worldcat.org'
    super(config)
  end

  def service_types_generated
    return [ServiceTypeValue['hilighted_link']]
  end
  
  def handle(request)    
    ref_metadata = request.referent.metadata
            
    isxn_key = nil
    isxn_value = nil
    if (! ref_metadata['issn'].blank?)
      isxn_key = 'issn'
      isxn_value = ref_metadata['issn']
    elsif (! ref_metadata['isbn'].blank?)
      isxn_key = 'isbn'
      isxn_value = ref_metadata['isbn']
    else
      # We have neither isbn nor issn, we can do nothing, but we
      # can do it succesfully
      return request.dispatched(self, true)
    end

    # We do a pre-emptive lookup to worldcat to try and see if worldcat
    # has a hit or not, before adding the link.
    uri_str = @base_url+isxn_key+'/'+isxn_value+"&loc=#{@search_zip_code}"
    if isxn_key == 'issn'
      uri_str += '+dt:ser' # avoid getting worldcat article records! Blah. 
    end
		worldcat_uri = URI.parse(uri_str)
		http = Net::HTTP.new worldcat_uri.host
		http.open_timeout = 3
		http.read_timeout = 2

    
		begin 
			wc_response = http.get(worldcat_uri.path)
		rescue  Timeout::Error
			return request.dispatched(self, DispatchedService::FailedTemporary)
		end

    # Bad response code?
		unless wc_response.code == "200"
      # Could be temporary, could be fatal. Let's say temporary. 
			return request.dispatched(self, DispatchedService::FailedTemporary)
		end

    # Sadly, worldcat returns a 200 even if there are no matches.
    # We need to screen-scrape to discover if there are matches.
    if (wc_response.body =~ /The page you tried was not found\./)
      # Not found in worldcat, we won't add a link.
      return request.dispatched(self, true)
    end
    
    #soup = BeautifulSoup.new wc_response.body    
		#return false if soup.title.string == "Find in a Library: "

    # Okay, actually add our link data. 
    
		#response.highlighted_links << {:type => "worldcat", :title =>"View record in Worldcat.org",:url => @worldcat_url+isxn+'/'+context_object.referent.metadata[isxn]+'&loc=30332'}

    request.add_service_response( {:service=>self, 
    :url=>worldcat_uri.to_s,
    :display_text=>@display_text}, 
    [ServiceTypeValue[:highlighted_link]]    )
    
    return request.dispatched(self, true)
  end
end
