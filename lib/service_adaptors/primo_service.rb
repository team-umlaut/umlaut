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
# * highlighted_link - parsed from links/addlink elements in the PNX record
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
#       - highlighted_link
# base_url:: _required_ host and port of Primo server; used for Primo web services, deep links and holding_search
# base_path:: *DEPRECATED* previous name of base_url
# vid:: _required_ view id for Primo deep links and holding_search.
# institution:: _required_ institution id for Primo institution; used for Primo web services
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
# primo_config::  _optional_ string representing the primo yaml config file in config/
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
  require 'exlibris-primo'

  required_config_params :base_url, :vid, :institution
  # For matching purposes.
  attr_reader :title, :author

  # Overwrites Service#new.
  def initialize(config)
    # Configure Primo
    configure_primo
    # Attributes for holding service data.
    @holding_attributes = [:record_id, :original_id, :title, :author, :display_type,
      :source_id, :original_source_id, :source_record_id, :ils_api_id, :institution_code,
      :institution, :library_code, :library, :collection, :call_number, :coverage, :notes,
      :subfields]
    @link_attributes = [:record_id, :original_id, :url, :display, :notes, :subfields]
    # TODO: Run these decisions someone to see if they make sense.
    @referent_enhancements = {
      # Prefer SFX journal titles to Primo journal titles
      :jtitle => { :overwrite => false },
      :btitle => { :overwrite => true },
      :aulast => { :overwrite => true },
      :aufirst => { :overwrite => true },
      :aucorp => { :overwrite => true },
      :au => { :overwrite => true },
      :pub => { :overwrite => true },
      :place => { :value => :cop, :overwrite => false },
      # Prefer SFX journal titles to Primo journal titles
      :title => { :value => :jtitle, :overwrite => false},
      :title => { :value => :btitle, :overwrite => true},
      # Primo lccn and oclcid are spotty in Primo, so don't overwrite
      :lccn => { :overwrite => false },
      :oclcnum => { :value => :oclcid, :overwrite => false}
    }
    @suppress_urls = []
    @suppress_tocs = []
    @suppress_related_links = []
    @suppress_holdings = []
    @service_types = [ "fulltext", "holding", "holding_search",
      "table_of_contents", "referent_enhance", "cover_image" ] if @service_types.nil?
    backward_compatibility(config)
    super(config)
    # For backward compatibility, handle the special case where holding_search_institution was not included.
    # Set holding_search_institution to vid and print warning in the logs.
    if @service_types.include?("holding_search") and @holding_search_institution.nil?
      @holding_search_institution = @institution
      Rails.logger.warn("Required parameter 'holding_search_institution' was not set.  Please set the appropriate value in services.yml.  Defaulting institution to view id, #{@vid}.")
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
    # Get the possible search params
    @identifier = request.referrer_id
    @record_id = record_id(request)
    @isbn = isbn(request)
    @title = title(request)
    @author = author(request)
    @genre = genre(request)
    # Setup the Primo search object
    search = Exlibris::Primo::Search.new.base_url!(@base_url).institution!(@institution)
    # Search if we have a:
    #   Primo record id OR
    #   ISBN OR
    #   ISSN OR
    #   Title and author and genre
    if @record_id
      search.record_id! @record_id
    elsif @isbn
      search.isbn_is @isbn
    elsif @issn
      search.isbn_is @issn
    elsif @title and @author and @genre
      search.title_is(@title).creator_is(@author).genre_is(@genre)
    else # Don't do a search.
      return request.dispatched(self, true)
    end

    begin
      records = search.records
      # Enhance the referent with metadata from Primo Searcher if Primo record id is present
      # i.e. if we did our search with the Primo system number
      if @record_id and @service_types.include?("referent_enhance")
        # We'll take the first record, since there should only be one.
        enhance_referent(request, records.first)
      end
      # Get cover image only if @record_id is defined
      # TODO: make cover image service smarter and only
      # include things that are actually URLs.
      # if @record_id and @service_types.include?("cover_image")
      #   cover_image = primo_searcher.cover_image
      #   unless cover_image.nil?
      #     request.add_service_response(
      #       :service => self,
      #       :display_text => 'Cover Image',
      #       :key => 'medium',
      #       :url => cover_image,
      #       :size => 'medium',
      #       :service_type_value => :cover_image)
      #   end
      # end
      # Add holding services
      if @service_types.include?("holding") or @service_types.include?("primo_source")
        # Get holdings from the returned Primo records
        holdings = records.collect{|record| record.holdings}.flatten
        # Add the holding services
        add_holding_services(request, holdings) unless holdings.empty?
        # Provide title search functionality in the absence of available holdings.
        # The logic below says only present the holdings search in the following case:
        #   We've configured to present holding search
        #   We didn't find any actual holdings
        #   We didn't come from Primo (prevent round trips since that would be weird)
        #   We have a title to search for.
        if @service_types.include?("holding_search") and holdings.empty? and (not primo_identifier?) and (not @title.nil?)
          # Add the holding search service
          add_holding_search_service(request)
        end
      end
      # Add fulltext services
      if @service_types.include?("fulltext")
        # Get fulltexts from the returned Primo records
        fulltexts = records.collect{|record| record.fulltexts}.flatten
        # Add the fulltext services
        add_fulltext_services(request, fulltexts) unless fulltexts.empty?
      end
      # Add table of contents services
      if @service_types.include?("table_of_contents")
        # Get tables of contents from the returned Primo records
        tables_of_contents = records.collect{|record| record.tables_of_contents}.flatten
        # Add the table of contents services
        add_table_of_contents_services(request, tables_of_contents) unless tables_of_contents.empty?
      end
      if @service_types.include?("highlighted_link")
        # Get related links from the returned Primo records
        highlighted_links = records.collect{|record| record.related_links}.flatten
        add_highlighted_link_services(request, highlighted_links) unless highlighted_links.empty?
      end
    rescue Exception => e
      # Log error and return finished
      Rails.logger.error(
        "Error in Exlibris::Primo::Search. "+
        "Returning 0 Primo services for search #{search.inspect}. "+
        "Exlibris::Primo::Search raised the following exception:\n#{e}\n#{e.backtrace.inspect}")
    end
    return request.dispatched(self, true)
  end

  # Called by ServiceType#view_data to provide custom functionality for Primo sources.
  # For more information on Primo sources see PrimoSource.
  def to_primo_source(service_response)
    source_parameters = { :base_url => @base_url, :vid => @vid }
    @holding_attributes.each { |attr|
      source_parameters[attr] = service_response.data_values[attr] }
    return Exlibris::Primo::Holding.new(source_parameters).to_source
  end

  # Configure Primo if this is the first time through
  def configure_primo
    Exlibris::Primo.configure do |primo_config|
      primo_config.load_yaml config_file unless primo_config.load_time
    end
  end
  private :configure_primo

  # Reset Primo configuration
  # Only used in testing
  def reset_primo_config
    Exlibris::Primo.configure do |primo_config|
      primo_config.load_time = nil
      primo_config.libraries = {}
      primo_config.availability_statuses = {}
      primo_config.sources = {}
    end
  end
  private :reset_primo_config

  # Enhance the referent based on metadata in the given record
  def enhance_referent(request, record)
    @referent_enhancements.each do |key, options|
      metadata_element = (options[:value].nil?) ? key : options[:value]
      # Enhance the referent from the 'addata' section
      metadata_method = "addata_#{metadata_element}".to_sym
      # Get the metadata value if it's there
      metadata_value = record.send(metadata_method) if record.respond_to? metadata_method
      # Enhance the referent
      request.referent.enhance_referent(key.to_s, metadata_value,
        true, false, options) unless metadata_value.nil?
    end
  end
  private :enhance_referent

  # Add a holding service for each holding returned from Primo
  def add_holding_services(request, holdings)
    holdings.each do |holding|
      next if @suppress_holdings.find {|suppress_holding| suppress_holding === holding.availlibrary}
      service_data = {}
      @holding_attributes.each do |attr|
        service_data[attr] = holding.send(attr)
      end
      # Umlaut specific attributes.
      service_data[:match_reliability] =
        (reliable_match?(:title => holding.title, :author => holding.author)) ?
          ServiceResponse::MatchExact : ServiceResponse::MatchUnsure
      service_data[:request_link_supports_ajax_call] =
        (holding.respond_to?(:request_link_supports_ajax_call)) ?
          holding.request_link_supports_ajax_call : false
      # Availability status from Primo is probably out of date, so set to "check_holdings"
      holding.availability_status_code = "check_holdings"
      # Add status
      service_data[:status_code] = holding.availability_status_code
      service_data[:status] = holding.availability_status
      # Add URL
      service_data[:url] =
        "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=#{holding.record_id}&institution=#{@institution}&vid=#{@vid}"
      # Only add one service type, either "primo_source" OR "holding", not both.
      service_type = (@service_types.include?("primo_source")) ? "primo_source" : "holding"
      # Add some other holding information for compatibility with default holding partial
      service_data.merge!({
        :call_number => holding.call_number, :collection => holding.collection,
        :collection_str => "#{holding.library} #{holding.collection}",
        :coverage_str => holding.coverage.join("<br />"),
        :coverage_str_array => holding.coverage }) if service_type.eql? "holding"
      request.add_service_response(
        service_data.merge(
          :service => self,
          :service_type_value => service_type))
    end
  end
  private :add_holding_services

  # Add a holding search service
  def add_holding_search_service(request)
    service_data = {}
    service_data[:type] = "link_to_search"
    service_data[:display_text] = (@holding_search_text.nil?) ? "Search for this title." : @holding_search_text
    service_data[:note] = ""
    service_data[:url] = @base_url+"/primo_library/libweb/action/dlSearch.do?institution=#{@holding_search_institution}&vid=#{@vid}&onCampus=false&query=#{CGI::escape("title,exact,"+@title)}&indx=1&bulkSize=10&group=GUEST"
    request.add_service_response(
      service_data.merge(
        :service => self,
        :service_type_value => 'holding_search'))
  end
  private :add_holding_search_service

  # Add a full text service for each fulltext returned from Primo
  def add_fulltext_services(request, fulltexts)
    add_link_services(request, fulltexts, 'fulltext', @suppress_urls) { |fulltext|
      # Don't add the URL if it matches our SFXUrl finder (unless fulltext is empty,
      # [assuming something is better than nothing]), because
      # that means we think this is an SFX controlled URL.
      next if SfxUrl.sfx_controls_url?(handle_ezproxy(fulltext.url)) and
        request.referent.metadata['genre'] != "book" and
          !request.get_service_type("fulltext", { :refresh => true }).empty?
    }
  end
  private :add_fulltext_services

  # Add a table of contents service for each table of contents returned from Primo
  def add_table_of_contents_services(request, tables_of_contents)
    add_link_services(request, tables_of_contents, 'table_of_contents', @suppress_tocs)
  end
  private :add_table_of_contents_services

  # Add a highlighted link service for each related link returned from Primo
  def add_highlighted_link_services(request, highlight_links)
    add_link_services(request, highlight_links, 'highlighted_link', @suppress_related_links)
  end
  private :add_highlighted_link_services

  # Add a link service (specified by the given type) for each link returned from Primo
  def add_link_services(request, links, service_type, suppress_links, &block)
    links_seen = [] # for de-duplicating urls
    links.each do |link|
      next if links_seen.include?(link.url)
      # Check the list of URLs to suppress, array of strings or regexps.
      # If we have a match, suppress.
      next if suppress_links.find {|suppress_link| suppress_link === link.url}
      # No url? Forget it.
      next if link.url.nil?
      yield link unless block.nil?
      links_seen.push(link.url)
      service_data = {}
      @link_attributes.each do |attr|
        service_data[attr] = link.send(attr)
      end
      # Default display text to URL.
      service_data[:display_text] = (service_data[:display].nil?) ? service_data[:url] : service_data[:display]
      # Add the response
      request.add_service_response(
        service_data.merge(
          :service => self,
          :service_type_value => service_type))
    end
  end
  private :add_link_services

  # Map old config names to new config names for backwards compatibility
  def backward_compatibility(config)
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
        Rails.logger.warn("Parameter '#{old_param}' is deprecated.  Please use '#{new_param}' instead.")
      end
    end # End backward compatibility maintenance
  end
  private :backward_compatibility

  # Determine how sure we are that this is a match.
  # Dynamically compares record metadata to input values
  # based on the values passed in.
  # Minimum requirement is to check title.
  def reliable_match?(record_metadata)
    return true unless (@record_id.nil? or @record_id.empty?)
    return true unless (@issn.nil? or @issn.empty?) and (@isbn.nil? or @isbn.empty?)
    return false if (record_metadata.nil? or record_metadata.empty? or record_metadata[:title].nil? or record_metadata[:title].empty?)
    # Titles must be equal
    return false unless record_metadata[:title].to_s.downcase.eql?(@title.downcase)
    # Author must be equal
    return false unless record_metadata[:author].to_s.downcase.eql?(@author.downcase)
    return true
  end
  private :reliable_match?

  def config_file
    default_file = "#{Rails.root}/config/primo.yml"
    config_file = @primo_config.nil? ? default_file : "#{Rails.root}/config/"+ @primo_config
    Rails.logger.warn("Primo config file not found: #{config_file}.") and return "" unless File.exists?(config_file)
    config_file
  end
  private :config_file

  # If an ezproxy prefix (on any other regexp) is hardcoded in the URL,
  # strip it out for matching against SFXUrls
  def handle_ezproxy(str)
    return str if @ez_proxy.nil?
    return (str.gsub(@ez_proxy, '').nil? ? str : str.gsub(@ez_proxy, ''))
  end
  private :handle_ezproxy

  def record_id(request)
    record_id = identifier.match(/primo-(.+)/)[1] if primo_identifier?
    # DEPRECATED
    # Extend OpenURL standard to take Primo Doc Id
    record_id = request.referent.metadata['primo'] unless request.referent.metadata['primo'].nil?
    Rails.logger.warn("Use of 'rft.primo' is deprecated.  Please use the identifier instead.") unless request.referent.metadata['primo'].nil?
    # End DEPRECATED
    record_id
  end
  private :record_id

  def isbn(request)
    request.referent.metadata['isbn']
  end
  private :isbn

  def issn(request)
    # don't send mal-formed issn
    request.referent.metadata['issn'] if request.referent.metadata['issn'] =~ /\d{4}(-)?\d{3}(\d|X)/
  end
  private :issn

  def title(request)
    (request.referent.metadata['jtitle'] || request.referent.metadata['btitle'] ||
      request.referent.metadata['title'] || request.referent.metadata['atitle'])
  end
  private :title

  def author(request)
    (request.referent.metadata['au'] || request.referent.metadata['aulast'] ||
      request.referent.metadata['aucorp'])
  end
  private :author

  def genre(request)
    request.referent.metadata['genre']
  end
  private :genre

  def primo_identifier?
    return false if @identifier.nil?
    return @identifier.start_with?('info:sid/primo.exlibrisgroup.com')
  end
  private :primo_identifier?
end