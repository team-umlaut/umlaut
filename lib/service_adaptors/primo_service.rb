# Needs to be called PrimoService to avoid conflicting with Primo module
# Params include:
# base_path:          host and port of Primo server.
#                     Used for web services and deep links
# base_view_id:       view id for Primo.
#                     Used for deep links
# goto_source:        either 0 or 1.
#                     Used to determine whether to link to Primo record or source record.
# suppress_urls:      array of strings or regexps to NOT use from the catalog.
#                     Used for urls that duplicate SFX targets but which aren't
#                     caught by SfxUrl.sfx_controls_url. Regexps can be put
#                     in the services.yml like this:    
#                        [!ruby/regexp '/sagepub.com$/']
# suppress_holdings:  array of strings or regexps to NOT use from the catalog.
#                     Used for urls that duplicate SFX targets but which aren't
#                     caught by SfxUrl.sfx_controls_url. Regexps can be put
#                     in the services.yml like this:    
#                        [!ruby/regexp '/\$\$LWEB$/']
# suppress_tocs:      array of strings or regexps to NOT link to for Tables of Contents.
#                     Used for urls that duplicate SFX targets but which aren't
#                     caught by SfxUrl.sfx_controls_url. Regexps can be put
#                     in the services.yml like this:    
#                        [!ruby/regexp '/\$\$LWEB$/']
# ez_proxy:           string or regexp of an ezproxy prefix. 
#                     Used in the case where an ezproxy prefix (on any other regexp) is hardcoded in the URL,
#                     and needs to be removed ino order to match against SFXUrls.
#                     Example:
#                        !ruby/regexp '/https\:\/\/ezproxy\.library\.nyu\.edu\/login\?url=/'
# primo_config:       string representing the primo yaml config file in umlaut_config
#                     default file: primo.yml
#                     hash mappings from yaml config
#                        libraries:
#                           "primo_library_code": "Primo Library String"
#                        statuses:
#                           "status1_code": "Status One"
#                        sources:
#                          data_source1:
#                            base_url: "http://source1.base.url
#                            type: source_type
#                            class_name: Source1Implementation (in exlibris/primo/sources)
#                          data_source2:
#                            base_url: "http://source2.base.url
#                            type: source_type
#                            class_name: Source2Implementation (in exlibris/primo/sources)
# Code copied from J. Rochkind HIP3Service
#   A holdings service could be abstracted out and extended for particular implementations

class PrimoService < Service
  required_config_params :base_path, :display_name, :base_view_id, :goto_source

  DEFAULT_FILE = "#{RAILS_ROOT}/config/umlaut_config/primo.yml"

  def initialize(config)
    # defaults
    @suppress_urls = []
    @suppress_tocs = []
    @suppress_holdings = []
    super(config)

    # Trim question-mark from base_url, if given
    @base_path.chop! if (@base_path.rindex('?') ==  @base_path.length)
  end

  # Standard method, used by background service updater. See Service docs. 
  def service_types_generated
    # We generate full text and holdings types, right now.
    types = [ ServiceTypeValue[:fulltext], ServiceTypeValue[:holding], ServiceTypeValue[:holding_search], ServiceTypeValue[:table_of_contents] ]
    #types = [ ServiceTypeValue[:fulltext], ServiceTypeValue[:holding] ]
    
    return types
  end
  
  def handle(request)
    # Extend OpenURL standard to take Primo Doc Id
    # Necessary for Primo Referrer
    primo_id = request.referent.metadata['primo']
    referrer = (request.referrer and  !request.referrer.identifier.nil? ? request.referrer.identifier : "")
    
    # Standard numbers
    issn = request.referent.metadata['issn']
    isbn = request.referent.metadata['isbn']
      
    # TODO: Implement title, author, genre search if ID/SNs don't exist.
    genre = request.referent.metadata['genre']
    
    # Generic Primo Searcher.
    primo_searcher = Exlibris::Primo::Searcher.new(@base_path, primo_config, @goto_source, @base_view_id)
    
    # Set Primo Searcher instance vars
    primo_searcher.referrer = referrer
    primo_searcher.primo_id = primo_id
    # don't send mal-formed issn
    primo_searcher.issn = issn if issn =~ /\d{4}(-)?\d{3}(\d|X)/
    primo_searcher.isbn = isbn
    primo_searcher.title = title
    primo_searcher.author = author
    primo_searcher.genre = genre

    # Get holdings from Primo Searcher
    holdings = primo_searcher.holdings # Array of Exlibris::Primo::Holding
    #Okay, we actually want to make each _copy_ into a service response.
    #A bib may have multiple copies. We are merging bibs, and just worrying
    #about the aggregated list of copies.
    holdings.each do |holding|
      # Won't match anything, but if reconfigured to point to src could be useful
      #next if urls_seen.include?(url)
      # Won't match anything, but if reconfigured to point to src could be useful
      # Don't add the Holding if it matches our SFXUrl finder, because
      # that means we think this is an SFX controlled URL.
      #next if SfxUrl.sfx_controls_url?(url)
      # We have our own list of Holdings to suppress, array of strings
      # or regexps.
      next if @suppress_holdings.find {|suppress| suppress === holding.text}
      service_data = {}
      service_data[:source_id] = holding.source_id
      service_data[:record_id] = holding.record_id
      service_data[:original_source_id] = holding.original_source_id
      service_data[:source_record_id] = holding.source_record_id
      service_data[:library_code] = holding.library_code
      service_data[:status_code] = holding.status_code
      service_data[:call_number] = holding.call_number
      service_data[:status] = holding.status
      service_data[:status_code] = holding.status_code
      service_data[:library] = holding.library
      service_data[:collection] = holding.collection
      service_data[:collection_str] = "#{holding.library} #{holding.collection}"
      service_data[:coverage_str] = holding.coverage_str
      service_data[:coverage_str_array] = holding.coverage_str_to_a 
      service_data[:notes] = holding.notes
      service_data[:url] = holding.url
      service_data[:request_url] = holding.request_url
      service_data[:display_text] = holding.text
      service_data[:match_reliability] = holding.match_reliability
      service_data[:request_link_supports_ajax_call] = holding.request_link_supports_ajax_call
      service_data[:expired] = false
      service_data[:latest] = true
      
      request.add_service_response( {:service=>self, :display_text => service_data[:display_text], :notes=>service_data[:notes], :url=> service_data[:url], :service_data=>service_data }, ['holding']  )

    end

    # Since this service runs to refresh the holdings availability, only get fulltext if none exist from Primo.
    fulltext_services  = request.get_service_type('fulltext', {})
    unless primo_service_exists?(fulltext_services)
      # Get URLs from Primo Searcher (executes search)
      urls = primo_searcher.urls # Array of Exlibris::Primo::Url

      # Let's find any URLs, and add full text responses for those.
      urls_seen = Array.new # for de-duplicating urls from catalog.
      urls.each do |primo_url|
        url = primo_url.url # actual url

        next if urls_seen.include?(url)
        # Don't add the URL if it matches our SFXUrl finder, because
        # that means we think this is an SFX controlled URL.
        # Handle EZProxy if hardcoded.
        next if (SfxUrl.sfx_controls_url?(handle_ezproxy(url)) and !(fulltext_services.empty?) and genre != "book")
        # We have our own list of URLs to suppress, array of strings
        # or regexps.
        next if @suppress_urls.find {|suppress| suppress === url}
      
        # No url? Forget it.
        next if url.nil?
      
        urls_seen.push(url)
      
        display_name = primo_url.display # URL display name, based on Primo Normalization Rules 
        display_name = url if display_name.nil? # set display name to URL if no other display name
      
        value_text = Hash.new

        value_text[:url] = url

        value_text[:notes] = primo_url.notes
        if ( value_text[:notes].blank?) 
          # TODO: Update for coverage, could be based on Primo Normalization Rules
          #value_text[:notes] += "Dates of coverage unknown."
        end

        response_params = {:service=>self, :display_text=>display_name, :url=>url, :notes=>value_text[:notes], :service_data=>value_text}
      
        # Add the response
        request.add_service_response(response_params, ['fulltext'])
      end
    end

    # Since this service runs to refresh the holdings availability, only get TOCs if none exist from Primo.
    toc_services  = request.get_service_type('table_of_contents', {})
    unless primo_service_exists?(toc_services)
      # Get TOCs from Primo Searcher
      tocs = primo_searcher.tocs # Array of Exlibris::Primo::Toc

      # Let's find any TOCs, and add table of contents responses for those.
      tocs_seen = Array.new # for de-duplicating urls from catalog.
      tocs.each do |primo_toc|
        url = primo_toc.url # actual url

        next if tocs_seen.include?(url)

        # We have our own list of URLs to suppress, array of strings
        # or regexps.
        next if @suppress_tocs.find {|suppress| suppress === url}
      
        # No url? Forget it.
        next if url.nil?
      
        tocs_seen.push(url)
      
        display_name = primo_toc.display # URL display name, based on Primo Normalization Rules 
        display_name = url if display_name.nil? # set display name to URL if no other display name
      
        value_text = Hash.new

        value_text[:url] = url

        value_text[:notes] = primo_toc.notes
        if ( value_text[:notes].blank?) 
          # TODO: Update for coverage, could be based on Primo Normalization Rules
          #value_text[:notes] += "Dates of coverage unknown."
        end

        response_params = {:service=>self, :display_text=>display_name, :url=>url, :notes=>value_text[:notes], :service_data=>value_text}
      
        # Add the response
        request.add_service_response(response_params, ['table_of_contents'])
      end

      # Provide title search functionality in the absence of available holdings.
      holding_search_services  = request.get_service_type('holding_search', {})
      if holdings.empty? and !primo_referrer?(referrer) and (!primo_service_exists?(holding_search_services)) and (!title.nil?)
        service_data = {}
        service_data[:type] = "link_to_search"
        service_data[:display_text] = (@link_to_search_text.nil?) ? "Search for this title." : @link_to_search_text
        service_data[:note] = ""
        service_data[:url] = @base_path+"/primo_library/libweb/action/dlSearch.do?institution=#{@base_view_id}&vid=#{@base_view_id}&onCampus=false&query=#{CGI::escape("title,exact,"+title)}&indx=1&bulkSize=10&group=GUEST"
        request.add_service_response( {:service=>self, :display_text => service_data[:display_text], :notes=>service_data[:notes], :url=> service_data[:url], :service_data=>service_data }, ['holding_search']  )
      end
    end

    return request.dispatched(self, true)
  end
  
  private
  # If an ezproxy prefix (on any other regexp) is hardcoded in the URL,
  # strip it out for matching against SFXUrls
  def handle_ezproxy(str)
    return str if @ez_proxy.nil?
    return (str.gsub(@ez_proxy, '').nil? ? str : str.gsub(@ez_proxy, ''))
  end

  def primo_config
    config_file = @primo_config.nil? ? DEFAULT_FILE : "#{RAILS_ROOT}/config/umlaut_config/"+ @primo_config
    YAML.load_file(config_file) if File.exists?(config_file)
  end
  
  def primo_service_exists?(service_types)
    service_types.each do |service_type|
      service_response = service_type.service_response
      if (service_response.service_id == "NYU_PRIMO")
        return true
      end
    end
    return false
  end

  def title
    return request.referent.metadata['jtitle'] unless request.referent.metadata['jtitle'].nil? or request.referent.metadata['jtitle'].empty?
    return request.referent.metadata['btitle'] unless request.referent.metadata['btitle'].nil? or request.referent.metadata['btitle'].empty?
    return request.referent.metadata['title'] unless request.referent.metadata['title'].nil? or request.referent.metadata['title'].empty?
    return request.referent.metadata['atitle'] unless request.referent.metadata['atitle'].nil? or request.referent.metadata['atitle'].empty?
  end

  def author
    return request.referent.metadata['au'] unless request.referent.metadata['au'].nil? or request.referent.metadata['au'].empty?
    return request.referent.metadata['aulast'] unless request.referent.metadata['aulast'].nil? or request.referent.metadata['aulast'].empty?
    return request.referent.metadata['aucorp'] unless request.referent.metadata['aucorp'].nil? or request.referent.metadata['aucorp'].empty?
  end

  def primo_referrer?(referrer)
    return false if referrer.nil?
    return (referrer.match('info:sid/primo.exlibrisgroup.com').nil? ? false : true)
  end

end
