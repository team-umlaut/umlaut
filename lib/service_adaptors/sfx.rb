# config parameters in services.yml
# name: display name
# base_url: 
# click_passthrough: When set to true, Umlaut will send all SFX clicks 
#     through SFX, for SFX to capture statistics. This is currently done
#     using a backdoor into the SFX sfxresolve.cgi script. Defaults to false, or the 
#     app_config.default_sfx_click_passthrough value.
# coverage_api_url: http url to the script Jonathan Rochkind wrote to interrogate
#     the SFX db to get 'coverage' information. Since SFX API does not currently provide
#     this info, this is 'extra' third-party API to do so.  [Not quite implemented yet].

class Sfx < Service
  require 'uri'
  require 'open_url'

  required_config_params :base_url
  
  def initialize(config)

    super(config)
  
    # class variable. Key is sfx service_type, value is umlaut servicetype string.
    # These are the SFX service types we will translate to umlaut
    "getFullTxt" || sfx_service_type == "getDocumentDelivery"
    @services_of_interest = {'getFullTxt'          => 'fulltext',
                             'getDocumentDelivery' => 'document_delivery'}
  
  end
  
  def handle(request)
    client = self.initialize_client(request)
    begin
      response = self.do_request(client)
      self.parse_response(response, request)
      return request.dispatched(self, true)
    rescue Errno::ETIMEDOUT
      # Request to SFX timed out. Record this as unsuccesful in the dispatch table. 
      return request.dispatched(self, false)
    end
  end
  
  def initialize_client(request)
    transport = OpenURL::Transport.new(@base_url)
    context_object = request.referent.to_context_object
    context_object.referrer.set_identifier(request.referrer.identifier)if request.referrer
    transport.add_context_object(context_object)
    transport.extra_args["sfx.response_type"]="multi_obj_xml"
    @get_coverage = false
    unless context_object.referent.metadata.has_key?("issue") or context_object.referent.metadata.has_key?("volume") or context_object.referent.metadata.has_key?("date")    
      transport.extra_args["sfx.ignore_date_threshold"]="1"
      transport.extra_args["sfx.show_availability"]="1"
      @get_coverage = true
    end
    if context_object.referent.identifier and context_object.referent.identifier.match(/^info:doi\//)
      transport.extra_args['sfx.doi_url']='http://dx.doi.org'
    end
    return transport
  end
  
  def do_request(client)
    client.transport_inline
    return client.response
  end
  
  def parse_response(resolver_response, request)
    require 'hpricot'
    require 'cgi'
    doc = Hpricot(resolver_response)     
    # parse perl_data from response
    related_items = []
    attr_xml = CGI.unescapeHTML((doc/"/ctx_obj_set/ctx_obj/ctx_obj_attributes").inner_html)
    perl_data = Hpricot(attr_xml)
    (perl_data/"//hash/item[@key='@sfx.related_object_ids']").each { | rel | 
      (rel/'/array/item').each { | item | 
        related_items << item.inner_html
      } 
    }
    
    object_id_node = (perl_data/"//hash/item[@key='rft.object_id']")
    object_id = nil
    if object_id_node
      object_id = object_id_node.inner_html
    end

    sfx_target_service_ids = doc.search('//target/target_service_id').collect {|e| e.inner_html}
    
    enhance_referent(request, perl_data)
    # generate new metadata object, since we have enhanced our metadata
    metadata = request.referent.metadata

    request_id = nil
    request_id_node = (perl_data/"//hash/item[@key='sfx.request_id']") 
    if request_id_node
      request_id = request_id_node.inner_html
    end    

    if object_id
      journal = Journal.find_by_object_id(object_id)
    elsif metadata['issn']
      journal = Journal.find_by_issn_or_eissn(metadata['issn'], metadata['eissn'])
    end  
    if journal
      journal.categories.each do | category |
        request.add_service_response({:service=>self,:key=>'SFX',:value_string=>category.category,:value_text=>category.subcategory},['subject'])
      end
    end

    # Load coverage/availability string from Rochkind's 'extra' SFX coverage API, if
    # configured, and if we have the right data to do so. We load em all in bulk in
    # one request, rather than a request per service. 
    loaded_coverage_strings = nil
    if ( @coverage_api_url && object_id && (sfx_target_service_ids.length > 0)  )      
      require 'net/http'
      require 'uri'
      require 'hpricot'

      loaded_coverage_strings = {}

      coverage_url = URI.parse(@coverage_api_url)
      coverage_url.query = "rft.object_id=#{object_id}&target_service_id=#{sfx_target_service_ids.join(',')}"
      
      response = Net::HTTP.get_response( coverage_url )
      unless (response.kind_of? Net::HTTPSuccess)
        response.error!
      end
      
      cov_doc = Hpricot( response.body )

      error = cov_doc.at('/sfxcoverage/exception')
      if ( error )
        logger.error("Error in SFX coverage API result. #{coverage_url.to_s} ; #{error.to_s}")
      end

      cov_doc.search('/sfxcoverage/targets/target').each do |target|
        service_id = target.at('target_service_id').inner_html
        coverage_str = target.at('availability_string').inner_html
        loaded_coverage_strings[service_id] = coverage_str
      end                        
    end

    # Each target delivered by SFX
    (doc/"/ctx_obj_set/ctx_obj/ctx_obj_targets/target").each_with_index do|target, target_index|  

      value_text = {}

      sfx_service_type = (target/"/service_type").inner_html
      umlaut_service = @services_of_interest[sfx_service_type]
      
      if ( umlaut_service ) # Okay, it's in services of interest

        if (target/"/displayer")
          source = "SFX/"+(target/"/displayer").inner_html
        else
          source = "SFX"+URI.parse(self.url).path
        end

        target_service_id = (target/"target_service_id").inner_html
        
        coverage = nil
        if (sfx_service_type == "getFullTxt" && @get_coverage )
          if ( loaded_coverage_strings ) # used the external extra SFX api
            coverage = loaded_coverage_strings[target_service_id]           
          elsif journal  # Umlaut journal index
            cvg = journal.coverages.find(:first, :conditions=>['provider = ?', (target/"/target_public_name").inner_html])
            coverage = cvg.coverage if cvg
          end
        end

        if ( sfx_service_type == 'getDocumentDelivery' )
          value_string = request_id
        else
          value_string = (target/"/target_service_id").inner_html          
        end
                
        value_text[:url] = CGI.unescapeHTML((target/"/target_url").inner_html)
        value_text[:notes] = CGI.unescapeHTML((target/"/note").inner_html)
        value_text[:source] = source
        value_text[:coverage] = coverage if coverage

        # Sfx metadata we want
        value_text[:sfx_target_index] = target_index + 1 # sfx is 1 indexed
        value_text[:sfx_request_id] = (perl_data/"//hash/item[@key='sfx.request_id']").first.inner_html
        value_text[:sfx_target_service_id] = target_service_id
        # At url-generation time, the request isn't available to us anymore,
        # so we better store this citation info here now, since we need it
        # for sfx click passthrough
        value_text[:citation_year] = metadata['date'] 
        value_text[:citation_volume] = metadata['volume'];
        value_text[:citation_issue] = metadata['issue']
        value_text[:citation_spage] = metadata['spage']
        

        request.add_service_response({:service=>self,:key=>(target/"/target_public_name").inner_html,:value_string=>value_string,:value_text=>value_text.to_yaml},[umlaut_service])
      end
    end   
  end
  
  def to_fulltext(response)  
    value_text = YAML.load(response.value_text)
    return {:display_text=>response.response_key, :note=>value_text[:note],:coverage=>value_text[:coverage],:source=>value_text[:source]}
  end
  
  def response_to_view_data(response)
    # default for any type, same as to_fulltext
    return to_fulltext(response)
  end
  
  def sfx_click_passthrough
    # From config, or if not that, from app default, or if not that, default
    # to false. 
    return @click_passthrough || AppConfig.default_sfx_click_passthrough || false;
  end
  
  def response_url(response)

    customData = YAML.load(response.value_text)
              
    if ( ! self.sfx_click_passthrough )
      return CGI.unescapeHTML(customData[:url])
    else
      # Okay, wacky abuse of SFX undocumented back-ends to pass the click
      # through SFX, so statistics are captured by SFX. 
      
      sfx_resolver_cgi_url =  @base_url + "/cgi/core/sfxresolver.cgi"      
      # Not sure if fixing tmp_ctx_obj_id to 1 is safe, but it seems to work,
      # and I don't know what the value is or how else to know it. 
      dataString = "?tmp_ctx_svc_id=#{customData[:sfx_target_index]}"
      dataString += "&tmp_ctx_obj_id=1&service_id=#{customData[:sfx_target_service_id]}"
      dataString += "&request_id=#{customData[:sfx_request_id]}"
      dataString += "&rft.year="
      dataString += customData[:citation_year].to_s if customData[:citation_year]
      dataString += "&rft.volume="
      dataString += customData[:citation_volume].to_s if customData[:citation_volume]
      dataString += "&rft.issue="
      dataString += customData[:citation_issue].to_s if customData[:citation_issue]
      dataString += "&rft.spage="
      dataString += customData[:citation_spage].to_s if customData[:citation_issue]

      return sfx_resolver_cgi_url + dataString       
    end
  end


  protected
  def enhance_referent(request, perl_data)
    metadata = request.referent.metadata
    
    if request.referent.format == 'journal'
        # If we already had metadata for journal title and the SFX one
        # differs, we want to over-write it. This is good for ambiguous
        # incoming OpenURLs, among other things.
        enhance_referent_value(request, "jtitle", (perl_data/"//hash/item[@key='rft.jtitle']"))                
    end
    
    if (request.referent.format == 'book' && ! metadata[btitle])      
        enhance_referent_value(request, 'btitle', (perl_data/"//hash/item[@key='rft.btitle']"))
    end

    unless metadata['issn']
      enhance_referent_value(request, 'issn', (perl_data/"//hash/item[@key='rft.issn']"))
    end
    
    unless metadata['eissn']
      enhance_referent_value(request, 'eissn', (perl_data/"//hash/item[@key='rft.eissn']"))
    end

    unless metadata['isbn']
      enhance_referent_value(request, 'isbn', (perl_data/"//hash/item[@key='rft.isbn']"))
    end

    unless metadata['genre']
      enhance_referent_value(request, 'genre', (perl_data/"//hash/item[@key='rft.genre']"))
    end
    
    unless metadata['issue']
      enhance_referent_value(request, 'issue', (perl_data/"//hash/item[@key='rft.issue']"))
    end

    unless metadata['volume']
      enhance_referent_value(request, 'volume', (perl_data/"//hash/item[@key='rft.volume']"))
    end
                    
  end

  # First arg is key for referent_value, second arg is an hpricot
  # element which we'll call .inner_html on to get the value.
  def enhance_referent_value(request, key, value_element)
    request.referent.enhance_referent(key, value_element.inner_html) if value_element
  end
  
end
