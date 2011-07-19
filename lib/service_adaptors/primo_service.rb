# == Overview
# PrimoService is a Service that makes a call to the Primo web services based on the OpenURL key value pairs.
#--
# NOT YET:
# It first looks for rft.primo *DEPRECATED*, failing that, it parses the identifier for an id.
#++
# It first looks for rft.primo, the Primo id.
# If the Primo id is present, the service gets the PNX record from the Primo web 
# services.
# If no Primo id is found, the service searches Primo by (in order of precedence):
# * ISBN
# * ISSN
# * Title, Author, Genre
#
# == Available Services
# Several service types are available in the Primo service.  The default service types are: 
# fulltext, holding, holding_search, table_of_contents, referent_enhance, cover_image
# Available service types are listed below and can be configured using the service_types parameter 
# in service.yml:
# * fulltext - parsed from links/linktorsrc elements in the PNX record
# * holding - parsed from display/availlibrary elements in the PNX record
# * holding_search - link to an exact title search in Primo if no holdings found AND the OpenURL did not come from Primo
# * primo_source - similar to holdings but used in conjuction with the PrimoSource service to map Primo records to their original sources; a PrimoSource service must be defined in service.yml for this to work
# * table_of_contents - parsed from links/linktotoc elements in the PNX record
# * referent_enhance - metadata parsed from the addata section of the PNX record when the record was found by Primo id
# * cover_image - parsed from first addata/lad02 element in the PNX record
#
# ==Available Parameters
# Several configurations parameters are available to be set in services.yml, e.g.
#   Primo:
#     type: PrimoService
#     priority: 2 # After SFX, to get SFX metadata enhancement
#     status: active
#     base_url: http://bobcat.library.nyu.edu
#     vid: NYU
#     holding_search_institution: NYU
#     holding_search_text: Search for this title in BobCat.
#     suppress_holdings: [ !ruby/regexp '/\$\$LWEB/', !ruby/regexp '/\$\$1Restricted Internet Resources/' ]
#     ez_proxy: !ruby/regexp '/https\:\/\/ezproxy\.library\.nyu\.edu\/login\?url=/'
#     service_types:
#       - holding
#       - holding_search
#       - fulltext
#       - table_of_contents
#       - referent_enhance
#       - cover_image
# base_url:: _required_ host and port of Primo server; used for Primo web services, deep links and holding_search
# base_path:: *DEPRECATED* previous name of base_url
# vid:: _required_ view id for Primo deep links and holding_search.
# base_view_id:: *DEPRECATED* previous name of vid
# holding_search_institution:: _required if service types include holding_search_ institution to be used for the holding_search
# holding_search_text:: _optional_ text to display for the holding_search
#                       default holding search text:: "Search for this title."
# link_to_search_text:: *DEPRECATED* previous name of holding_search_text
# service_types:: _optional_ array of strings that represent the service types desired.
#                 options are: fulltext, holding, holding_search, table_of_contents,
#                 referent_enhance, cover_image, primo_source
#                 defaults are: fulltext, holding, holding_search, table_of_contents,
#                 referent_enhance, cover_image
#                 if no options are specified, default service types will be added.
# suppress_urls:: _optional_ array of strings or regexps to NOT use from the catalog.
#                 Used for linktorsrc elements that may duplicate resources from in other services.
#                 Regexps can be put in the services.yml like this:    
#                     [!ruby/regexp '/sagepub.com$/']
# suppress_holdings:: _optional_ array of strings or regexps to NOT use from the catalog.
#                     Used for availlibrary elements that may duplicate resources from in other services.
#                     Regexps can be put in the services.yml like this:    
#                         [!ruby/regexp '/\$\$LWEB$/']
# suppress_tocs:: _optional_ array of strings or regexps to NOT link to for Tables of Contents.
#                 Used for linktotoc elements that may duplicate resources from in other services.
#                 Regexps can be put in the services.yml like this:    
#                     [!ruby/regexp '/\$\$LWEB$/']
# service_types:: _optional_ array of strings that represent the service types desired.
#                 options are: fulltext, holding, holding_search, table_of_contents,
#                 referent_enhance, cover_image, primo_source
#                 defaults are: fulltext, holding, holding_search, table_of_contents,
#                 referent_enhance, cover_image
#                 if no options are specified, default service types will be added.
# ez_proxy::  _optional_ string or regexp of an ezproxy prefix. 
#             used in the case where an ezproxy prefix (on any other regexp) is hardcoded in the URL,
#             and needs to be removed in order to match against SFXUrls.
#             Example:
#                 !ruby/regexp '/https\:\/\/ezproxy\.library\.nyu\.edu\/login\?url=/'
# primo_config::  _optional_ string representing the primo yaml config file in config/umlaut_config
#                 default file name: primo.yml
#                 hash mappings from yaml config
#                    institutions:
#                       "primo_institution_code": "Primo Institution String"
#                    libraries:
#                       "primo_library_code": "Primo Library String"
#                    statuses:
#                       "status1_code": "Status One"
#                    sources:
#                      data_source1:
#                        base_url: "http://source1.base.url
#                        type: source_type
#                        class_name: Source1Implementation (in exlibris/primo/sources or exlibris/primo/sources/local)
#                        source1_config_option1: source1_config_option1
#                        source1_config_option2: source1_config_option2
#                      data_source2:
#                        base_url: "http://source2.base.url
#                        type: source_type
#                        class_name: Source2Implementation (in exlibris/primo/sources or exlibris/primo/sources/local)
#                        source2_config_option1: source2_config_option1
#                        source2_config_option2: source2_config_option2
# holding_attributes::  _optional_ array of Holding attribute readers to save to 
#                       holding/primo_source service_data; can be used to save 
#                       custom source implementation attributes for display by a custom holding partial
# ==Benchmarks
# The following benchmarks were run on SunOS 5.10 Generic_141414-08 sun4u sparc SUNW,Sun-Fire-V240.
#       Rehearsal ----------------------------------------------------------------
#       PrimoService Minimum Config:   3.850000   0.060000   3.910000 (  4.163065)
#       PrimoService Default Config:   3.410000   0.060000   3.470000 (  3.958777)
#       ------------------------------------------------------- total: 7.380000sec
#       
#                                        user     system      total        real
#       PrimoService Minimum Config:   3.470000   0.050000   3.520000 (  4.567797)
#       PrimoService Default Config:   3.420000   0.050000   3.470000 (  3.990271)

class PrimoService < Service
  required_config_params :base_url, :vid

  # Overwrites Service#new.
  def initialize(config)
    # defaults
    @holding_attributes = Exlibris::Primo::Holding.base_attributes
    @rsrc_attributes = Exlibris::Primo::Rsrc.base_attributes
    @toc_attributes = Exlibris::Primo::Toc.base_attributes
    # TODO: Run these decisions by Bill M. to see if they make sense.
    @referent_enhancements = {
      # Prefer SFX journal titles to Primo journal titles
      :jtitle => { :overwrite => false },
      :btitle => { :overwrite => true }, :aulast => { :overwrite => true },
      :aufirst => { :overwrite => true }, :aucorp => { :overwrite => true }, 
      :au => { :overwrite => true }, :pub => { :overwrite => true },
      :place => { :value => :cop, :overwrite => false },
      # Prefer SFX journal titles to Primo journal titles
      :title => { :value => :jtitle, :overwrite => false},
      :title => { :value => :btitle, :overwrite => true},
      # Primo lccn and oclcid are spotty in Primo, so don't overwrite
      :lccn => { :overwrite => false }, :oclcnum => { :value => :oclcid, :overwrite => false}
    }
    @suppress_urls = []
    @suppress_tocs = []
    @suppress_holdings = []
    @service_types = [ "fulltext", "holding", "holding_search",
      "table_of_contents", "referent_enhance", "cover_image" ] if @service_types.nil?
    # For backward compatibility, re-map "old" config values to new more 
    # Umlaut-y names and print deprecation warning in the logs.
    old_to_new_mappings = {
      :base_path => :base_url,
      :base_view_id => :vid,
      :link_to_search_text => :holding_search_text
    }
    old_to_new_mappings.each do |old_param, new_param|
      unless config["#{old_param}"].nil?
        config["#{new_param}"] = config["#{old_param}"] if config["#{new_param}"].nil?
        RAILS_DEFAULT_LOGGER.warn("Parameter '#{old_param}' is deprecated.  Please use '#{new_param}' instead.")
      end
    end # End backward compatibility maintenance
    super(config)
    # For backward compatibility, handle the special case where holding_search_institution was not included.
    # Set holding_search_institution to vid and print warning in the logs.
    if @service_types.include?("holding_search") and @holding_search_institution.nil?
      @holding_search_institution = @vid
      RAILS_DEFAULT_LOGGER.warn("Required parameter 'holding_search_institution' was not set.  Please set the appropriate value in services.yml.  Defaulting institution to view id, #{@vid}.")
    end # End backward compatibility maintenance
    raise ArgumentError.new(
      "Missing Service configuration parameter. Service type #{self.class} (id: #{self.id}) requires a config parameter named 'holding_search_institution'. Check your config/umlaut_config/services.yml file."
    ) if @service_types.include?("holding_search") and @holding_search_institution.nil?
  end

  # Overwrites Service#service_types_generated.
  def service_types_generated
    types = Array.new
    @service_types.each do |type|
      types.push(ServiceTypeValue[type.to_sym])
    end
    return types
  end
  
  # Overwrites Service#handle.
  def handle(request)
    @identifier = request.referrer.identifier if request.referrer and request.referrer.identifier
    primo_id = @identifier.match(/primo-(.+)/)[1] if primo_identifier?
    # DEPRECATED
    # Extend OpenURL standard to take Primo Doc Id
    primo_id = request.referent.metadata['primo'] unless request.referent.metadata['primo'].nil?
    RAILS_DEFAULT_LOGGER.warn("Use of 'rft.primo' is deprecated.  Please use the identifier instead.") unless request.referent.metadata['primo'].nil?
    # End DEPRECATED
    searcher_setup = {
      :base_url => @base_url, :vid => @vid,
      :config => primo_config
    }
    # don't send mal-formed issn
    issn = request.referent.metadata['issn'] if request.referent.metadata['issn'] =~ /\d{4}(-)?\d{3}(\d|X)/
    title = title(request)
    search_params = {
      :primo_id => primo_id,
      :isbn => request.referent.metadata['isbn'], 
      :issn => issn,
      :title => title,
      :author => author(request),
      :genre => request.referent.metadata['genre']
    }
    begin
       primo_searcher = Exlibris::Primo::Searcher.new(searcher_setup, search_params)
    rescue Exception => e
      # Log error and return finished
      RAILS_DEFAULT_LOGGER.error(
        "Error in Exlibris::Primo::Searcher. "+ 
        "Returning 0 Primo services for search #{search_params.inspect}. "+ 
        "Exlibris::Primo::Searcher raised the following exception:\n#{e}")
      return request.dispatched(self, true)
    end
    # Enhance the referent with metadata from Primo Searcher if primo id is present
    # i.e. if we did our search with the Primo system number
    if primo_id and @service_types.include?("referent_enhance")
      @referent_enhancements.each do |key, options|
        value = (options[:value].nil?) ? key.to_sym : options[:value].to_sym
        request.referent.enhance_referent(
          key.to_s, primo_searcher.method(value).call, 
          true, false, options
        ) if primo_searcher.respond_to? value and not primo_searcher.method(value).call.nil?
      end
    end
    # Get cover image only if primo_id is defined
    if primo_id and @service_types.include?("referent_enhance")
      cover_image = primo_searcher.cover_image
      unless cover_image.nil?
        request.add_service_response({
          :service => self, 
          :display_text => 'Cover Image',
          :key => 'medium', 
          :url => cover_image, 
          :service_data => {:size => 'medium' }
        }, [ServiceTypeValue[:cover_image]])
      end
    end
    # Get holdings from Primo Searcher
    if @service_types.include?("holding") or @service_types.include?("primo_source")
      holdings = primo_searcher.holdings # Array of Exlibris::Primo::Holding
      holdings.each do |holding|
        next if @suppress_holdings.find {|suppress| suppress === holding.availlibrary}
        service_data = {}
        @holding_attributes.each do |attr|
          service_data[attr] = holding.method(attr).call
        end
        # Only add one service type, either "primo_source" OR "holding", not both.
        service_type = (@service_types.include?("primo_source")) ? "primo_source" : "holding"
        # Add some other holding information for compatibility with default holding partial
        service_data.merge!({ 
          :call_number => holding.call_number, :collection => holding.collection,
          :collection_str => "#{holding.library} #{holding.collection}",
          :coverage_str => holding.coverage.join("<br />"), 
          :coverage_str_array => holding.coverage }) if service_type.eql? "holding"
        request.add_service_response(
          { :service => self,
            :notes => service_data[:notes],
            :url => service_data[:url],
            :service_data => service_data }, [ service_type ] )
      end
      # Provide title search functionality in the absence of available holdings.
      if @service_types.include?("holding_search")
        if holdings.empty? and
           not primo_identifier? and 
           not title.nil?
          service_data = {}
          service_data[:type] = "link_to_search"
          service_data[:display_text] = (@holding_search_text.nil?) ? "Search for this title." : @holding_search_text
          service_data[:note] = ""
          service_data[:url] = @base_url+"/primo_library/libweb/action/dlSearch.do?institution=#{@holding_search_institution}&vid=#{@vid}&onCampus=false&query=#{CGI::escape("title,exact,"+title)}&indx=1&bulkSize=10&group=GUEST"
          request.add_service_response({
            :service => self,
            :display_text => service_data[:display_text],
            :notes =>service_data[:notes],
            :url => service_data[:url],
            :service_data => service_data }, ['holding_search'] )
        end
      end
    end
    # Get fulltext
    if @service_types.include?("fulltext")
      # Get RSRCs from Primo Searcher (executes search)
      # Let's find any URLs, and add full text responses for those.
      urls_seen = [] # for de-duplicating urls from catalog.
      primo_searcher.rsrcs.each do |rsrc|
        next if urls_seen.include?(rsrc.url)
        # Don't add the URL if it matches our SFXUrl finder, because
        # that means we think this is an SFX controlled URL.
        # Handle EZProxy if hardcoded.
        next if SfxUrl.sfx_controls_url?(handle_ezproxy(rsrc.url)) and 
          request.referent.metadata['genre'] != "book"
        # We have our own list of URLs to suppress, array of strings
        # or regexps.
        next if @suppress_urls.find {|suppress| suppress === rsrc.url}
        # No url? Forget it.
        next if rsrc.url.nil?
        urls_seen.push(rsrc.url)
        service_data = {}
        @rsrc_attributes.each do |attr|
          service_data[attr] = rsrc.method(attr).call
        end
        # Default display text to URL.
        service_data[:display_text] = (service_data[:display].nil?) ? service_data[:url] : service_data[:display]
        # Add the response
        request.add_service_response({
          :service => self,
          :display_text => service_data[:display_text],
          :url => service_data[:url],
          :notes => service_data[:notes],
          :service_data => service_data }, ['fulltext'] )
      end
    end
    # Get TOCs
    if @service_types.include?("table_of_contents")
      # Let's find any TOCs, and add table of contents responses for those.
      tocs_seen = [] # for de-duplicating urls from catalog.
      primo_searcher.tocs.each do |toc|
        url = toc.url # actual url
        next if tocs_seen.include?(toc.url)
        # We have our own list of URLs to suppress, array of strings
        # or regexps.
        next if @suppress_tocs.find {|suppress| suppress === toc.url}
        # No url? Forget it.
        next if toc.url.nil?
        tocs_seen.push(toc.url)
        service_data = {}
        @toc_attributes.each do |attr|
          service_data[attr] = toc.method(attr).call
        end
        # Default display text to URL.
        service_data[:display_text] = (service_data[:display].nil?) ? service_data[:url] : service_data[:display]
        # Add the response
        request.add_service_response({ 
          :service => self,
          :display_text => service_data[:display_text],
          :url => service_data[:url],
          :notes => service_data[:notes],
          :service_data => service_data }, ['table_of_contents'] )
      end
    end
    return request.dispatched(self, true)
  end

  # Called by ServiceType#view_data to provide custom functionality for Primo sources.
  # For more information on Primo sources see PrimoSource.
  def to_primo_source(service_response)
    source_parameters = { :base_url => @base_url, :vid => @vid, :config => primo_config }
    @holding_attributes.each { |attr| 
        source_parameters[attr] = service_response.data_values[attr] }
    return Exlibris::Primo::Holding.new(source_parameters).to_source
  end
  
  private
  def primo_config
    default_file = "#{RAILS_ROOT}/config/umlaut_config/primo.yml"
    config_file = @primo_config.nil? ? default_file : "#{RAILS_ROOT}/config/umlaut_config/"+ @primo_config
    RAILS_DEFAULT_LOGGER.warn("Primo config file not found: #{config_file}.") and return {} unless File.exists?(config_file)
    config_hash = YAML.load_file(config_file)
    return (config_hash.nil?) ? {} : config_hash
  end
  
  # If an ezproxy prefix (on any other regexp) is hardcoded in the URL,
  # strip it out for matching against SFXUrls
  def handle_ezproxy(str)
    return str if @ez_proxy.nil?
    return (str.gsub(@ez_proxy, '').nil? ? str : str.gsub(@ez_proxy, ''))
  end

  def title(request)
    return request.referent.metadata['jtitle'] unless request.referent.metadata['jtitle'].nil? or request.referent.metadata['jtitle'].empty?
    return request.referent.metadata['btitle'] unless request.referent.metadata['btitle'].nil? or request.referent.metadata['btitle'].empty?
    return request.referent.metadata['title'] unless request.referent.metadata['title'].nil? or request.referent.metadata['title'].empty?
    return request.referent.metadata['atitle'] unless request.referent.metadata['atitle'].nil? or request.referent.metadata['atitle'].empty?
  end

  def author(request)
    return request.referent.metadata['au'] unless request.referent.metadata['au'].nil? or request.referent.metadata['au'].empty?
    return request.referent.metadata['aulast'] unless request.referent.metadata['aulast'].nil? or request.referent.metadata['aulast'].empty?
    return request.referent.metadata['aucorp'] unless request.referent.metadata['aucorp'].nil? or request.referent.metadata['aucorp'].empty?
  end

  def primo_identifier?
    return false if @identifier.nil?
    return (@identifier.match('info:sid/primo.exlibrisgroup.com').nil?) ? false : true
  end
end
