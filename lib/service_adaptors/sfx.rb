# config parameters in services.yml
# display name: User displayable name for this service
# base_url: SFX base url. 
# click_passthrough: When set to true, Umlaut will send all SFX clicks 
#     through SFX, for SFX to capture statistics. This is currently done
#     using a backdoor into the SFX sfxresolve.cgi script. Defaults to false,
#     or the app_config.default_sfx_click_passthrough config if set
# coverage_api_url: http url to the script Jonathan Rochkind wrote to
#     interrogate the SFX db to get 'coverage' information. Since SFX API does
#     not currently provide this info, this is 'extra' third-party API to do so.
# services_of_interest: Optional. over-ride the built in list of what types of 
#     SFX services we want to grab, and what the corresponding umlaut types are.
#     hash, with SFX service type name as key, and Umlaut ServiceTypeValue
#     name as value. 
# extra_targets_of_interest: sfx target_names of targets you want to make
#     sure to include in umlaut. A hash with target_name as key, and umlaut
#     ResponseTypeValue name as value.
class Sfx < Service
  require 'uri'
  require 'open_url'

  required_config_params :base_url
  
  def initialize(config)

    # Key is sfx service_type, value is umlaut servicetype string.
    # These are the SFX service types we will translate to umlaut
    @services_of_interest = {'getFullTxt'          => 'fulltext',
                             'getSelectedFullTxt'  => 'fulltext',
                             'getDocumentDelivery' => 'document_delivery',                         
                             'getDOI'              => 'highlighted_link',
                             'getAbstract'         => 'abstract',
                             'getTOC'              => 'table_of_contents'}

    # Special targets. Key is SFX target_name.
    # Value is umlaut service type.
    # These targets will be included even if their sfx service_type doesn't
    # match our services_of_interest, and the umlaut service ID string given
    # here will take precedence and be used even if these targets DO match
    # services_of_interest. Generally loaded from yml config in super.    
    @extra_targets_of_interest = {}
                                  
    super(config)                              
  end

  # Standard method, used by auto background updater. See Service docs. 
  def service_types_generated
    service_strings = []
    service_strings.concat( @services_of_interest.values() )
    service_strings.concat( @extra_targets_of_interest.values() )
    service_strings.uniq!

    return service_strings.collect { |s| ServiceTypeValue[s] }
  end

  def base_url
    return @base_url
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
    #context_object = request.referent.to_context_object
    #context_object.referrer.add_identifier(request.referrer.identifier) if request.referrer

    context_object = request.to_context_object
    
    transport.add_context_object(context_object)
    transport.extra_args["sfx.response_type"]="multi_obj_xml"
    
    @get_coverage = false
    if (context_object.referent.metadata["issue"].blank? && context_object.referent.metadata["volume"].blank? && context_object.referent.metadata["date"].blank?)    
      transport.extra_args["sfx.ignore_date_threshold"]="1"
      transport.extra_args["sfx.show_availability"]="1"
      @get_coverage = true
    end
    # Workaround to SFX bug, not sure if this is really still neccesary
    # I think it's not, but leave it in anyway just in case. 
    if (context_object.referent.identifiers.find {|i| i =~ /^info:doi\// })
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
    
    #journal_index_on = AppConfig.param("use_umlaut_journal_index", true)
    # Bug in appconfig
    journal_index_on = AppConfig["use_umlaut_journal_index"]
    journal_index_on = false if journal_index_on.nil?
    
    doc = Hpricot(resolver_response)     
    # parse perl_data from response
    related_items = []
    # For god's sake, if there is more than one context object in our multi
    # response, just take the perl data from the FIRST one. Otherwise we end up
    # with a mess in enhanced metadata! 
    attr_xml = CGI.unescapeHTML((doc/"/ctx_obj_set/ctx_obj/ctx_obj_attributes")[0].inner_html)
    perl_data = Hpricot(attr_xml)
    (perl_data/"//hash/item[@key='@sfx.related_object_ids']").each { | rel | 
      (rel/'/array/item').each { | item | 
        related_items << item.inner_html
      } 
    }

    object_id_node = perl_data.at("//hash/item[@key='rft.object_id']")
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

    if ( journal_index_on )
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
    end

    # Load coverage/availability string from Rochkind's 'extra' SFX coverage API, if
    # configured, and if we have the right data to do so. We load em all in bulk in
    # one request, rather than a request per service. 
    loaded_coverage_strings = nil
    if ( @get_coverage && @coverage_api_url && object_id  && (sfx_target_service_ids.length > 0)  )
      begin
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
          request.logger.error("Error in SFX coverage API result. #{coverage_url.to_s} ; #{error.to_s}")
          raise "Error in coverage API fetch"
        end
  
        cov_doc.search('/sfxcoverage/targets/target').each do |target|
          service_id = target.at('target_service_id').inner_html
          coverage_str = target.at('availability_string').inner_html
          loaded_coverage_strings[service_id] = coverage_str
        end                              
      rescue Exception
          sfx_target_service_ids.each { |id| loaded_coverage_strings[id] = "Error in fetching coverage information." }
      end
    end

    # Each target delivered by SFX
    (doc/"/ctx_obj_set/ctx_obj/ctx_obj_targets/target").each_with_index do|target, target_index|  
      value_text = {}

      # First check @extra_targets_of_interest
      sfx_target_name = target.at('target_name').inner_html
      umlaut_service = @extra_targets_of_interest[sfx_target_name]

      # If not found, look for it in services_of_interest
      unless ( umlaut_service )
        sfx_service_type = target.at("/service_type").inner_html
        umlaut_service = @services_of_interest[sfx_service_type]
      end
      
      if ( umlaut_service ) # Okay, it's in services or targets of interest

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
          elsif (journal_index_on && journal)  # Umlaut journal index
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

        display_text = (target/"/target_public_name").inner_html

        #        :value_text=>value_text.to_yaml,

        initHash = {:service=>self,
        #:value_text=>value_text.to_yaml,
        :service_data=>value_text, :display_text=>display_text,
        :notes=>value_text[:notes]}
        request.add_service_response(initHash , [umlaut_service])
      end
    end   
  end
  
  
  def sfx_click_passthrough
    # From config, or if not that, from app default, or if not that, default
    # to false. 
    return @click_passthrough || AppConfig.default_sfx_click_passthrough || false;
  end

  # Handles click passthrough to SFX, if configured so. 
  def response_url(response)              
    if ( ! self.sfx_click_passthrough )
      return CGI.unescapeHTML(response[:url])
    else
      # Okay, wacky abuse of SFX undocumented back-ends to pass the click
      # through SFX, so statistics are captured by SFX. 
      
      sfx_resolver_cgi_url =  @base_url + "/cgi/core/sfxresolver.cgi"      
      # Not sure if fixing tmp_ctx_obj_id to 1 is safe, but it seems to work,
      # and I don't know what the value is or how else to know it. 
      dataString = "?tmp_ctx_svc_id=#{response[:sfx_target_index]}"
      dataString += "&tmp_ctx_obj_id=1&service_id=#{response[:sfx_target_service_id]}"
      dataString += "&request_id=#{response[:sfx_request_id]}"
      dataString += "&rft.year="
      dataString += response[:citation_year].to_s if response[:citation_year]
      dataString += "&rft.volume="
      dataString += response[:citation_volume].to_s if response[:citation_volume]
      dataString += "&rft.issue="
      dataString += response[:citation_issue].to_s if response[:citation_issue]
      dataString += "&rft.spage="
      dataString += response[:citation_spage].to_s if response[:citation_issue]

      return sfx_resolver_cgi_url + dataString       
    end
  end


  # Class method to parse a perl_data block as XML in String
  # into a ContextObject. Argument is _string_ containing
  # XML!
  def self.parse_perl_data(perl_data)
    doc = Hpricot(perl_data)

    co = OpenURL::ContextObject.new
    co.referent.set_format('journal') # default
    
    doc.search('hash/item').each do |item|
      key = item['key']
      prefix, stripped = key.split('.')
      value = item.inner_html
      
      # Darn multi-value SFX hackery. Just take the first one,
      # our context object can't store more than one. 
      if (prefix == '@rft')
        array_items = item.search("array/item")
        array_i = array_items[0] unless array_items.blank?
        
        prefix = 'rft' if array_i
        value = array_i.inner_html if array_i  
      end

      # object_type? Fix that to be the right way.
      if (prefix=='rft') && (key=='object_type')
        co.referent.set_format( value.downcase )
        next
      end
      
      if (prefix == 'rft' && value)
          co.referent.set_metadata(stripped, item.inner_html)
      end

      if (prefix=='@rft_id')
          identifiers = item.search('array/item')
          identifiers.each do |id|
            co.referent.add_identifier(id.inner_html)
          end
      end
      if (prefix=='@rfr_id')
          identifiers = item.search('array/item')
          identifiers.each do |id|
            co.referrer.add_identifier(id.inner_html)
          end
      end
    end

    return co
  end

  protected
  def enhance_referent(request, perl_data)
    metadata = request.referent.metadata

    sfx_co = Sfx.parse_perl_data(perl_data.to_s)
    sfx_metadata = sfx_co.referent.metadata
    # For reasons not understood by me, including the rft.object_id, which
    # should be SFX's internal object ID, in a later request, messes things up.
    # So eliminate it.
    sfx_metadata.delete('object_id')
    # some of these others are funky too, since it's an array
    sfx_metadata.delete('stitle')
    sfx_metadata.delete('auinit')
    sfx_metadata.delete('aulast')

    # If we already had metadata for journal title and the SFX one
    # differs, we want to over-write it. This is good for ambiguous
    # incoming OpenURLs, among other things.
    # Actually, SFX messes up titles of non-ascii-7 (ie, diacritics etc)
    # in XML, so we don't really want to do that after all, sadly.
    
    #if request.referent.format == 'journal'
    #    request.referent.enhance_referent("jtitle", sfx_metadata['jtitle'])
    #end
    # Let's do it with ISSN though
    if request.referent.format == 'journal' && ! sfx_metadata['issn'].blank?
      request.referent.enhance_referent('issn', sfx_metadata['issn'])
    end

    # The rest,  we write only if blank, we don't over-write
    sfx_metadata.each do |key, value|      
      if (metadata[key].blank?)
        request.referent.enhance_referent(key, value)
      end
    end
                        
  end

  
  end
  
