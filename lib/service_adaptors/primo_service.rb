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
    # Configure Primo if this is the first time through
    Exlibris::Primo.configure do |config|
      config.load_yaml config_file unless config.load_time
    end
    # Defaults
    @holding_attributes = Exlibris::Primo::Holding.base_attributes
    @rsrc_attributes = Exlibris::Primo::Rsrc.base_attributes
    @toc_attributes = Exlibris::Primo::Toc.base_attributes
    @related_link_attributes = Exlibris::Primo::RelatedLink.base_attributes
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
    rescue Exception => e
      # Log error and return finished
      Rails.logger.error(
        "Error in Exlibris::Primo::Searcher. "+
        "Returning 0 Primo services for search #{search_params.inspect}. "+
        "Exlibris::Primo::Searcher raised the following exception:\n#{e}\n#{e.backtrace.inspect}")
      return request.dispatched(self, true)
    end
    # Get cover image only if @primo_id is defined
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
    # Get holdings from Primo Searcher
    if @service_types.include?("holding") or @service_types.include?("primo_source")
      records.each do |record|
        record.holdings.each do |holding|
          next if @suppress_holdings.find {|suppress| suppress === holding.availlibrary}
          service_data = {}
          @holding_attributes.each do |attr|
            service_data[attr] = holding.method(attr).call
          end
          # Umlaut specific attributes.
          service_data[:match_reliability] =
            (reliable_match?(:title => holding.title, :author => holding.author)) ?
              ServiceResponse::MatchExact : ServiceResponse::MatchUnsure
          service_data[:request_link_supports_ajax_call] =
            (holding.respond_to?(:request_link_supports_ajax_call)) ?
              holding.request_link_supports_ajax_call : false
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
              :service_type_value => service_type
            )
          )
        end
      end
      # Provide title search functionality in the absence of available holdings.
      # The logic below says only present the holdings search in the following case:
      #   We've configured to present holding search
      #   We didn't find any actual holdings
      #   We didn't come from Primo (prevent round trips since that would be weird)
      #   We have a title to search for.
      if @service_types.include?("holding_search") and holdings.empty? and (not primo_identifier?)
        if holdings.empty? and
            and
           not @title.nil?
          service_data = {}
          service_data[:type] = "link_to_search"
          service_data[:display_text] = (@holding_search_text.nil?) ? "Search for this title." : @holding_search_text
          service_data[:note] = ""
          service_data[:url] = @base_url+"/primo_library/libweb/action/dlSearch.do?institution=#{@holding_search_institution}&vid=#{@vid}&onCampus=false&query=#{CGI::escape("title,exact,"+@title)}&indx=1&bulkSize=10&group=GUEST"
          request.add_service_response(
            service_data.merge(
              :service => self,
              :service_type_value => 'holding_search'
            )
          )
        end
      end
    end
    # Get fulltext
    if @service_types.include?("fulltext")
      # Get RSRCs from Primo Searcher (executes search)
      # Let's find any URLs, and add full text responses for those.
      urls_seen = [] # for de-duplicating urls from catalog.
      primo_searcher.rsrcs.each do |rsrc|
        # No url? Forget it.
        next if rsrc.url.nil?
        # Next if duplicate.
        next if urls_seen.include?(rsrc.url)
        # Don't add the URL if it matches our SFXUrl finder (unless fulltext is empty,
        # [assuming something is better than nothing]), because
        # that means we think this is an SFX controlled URL.
        next if SfxUrl.sfx_controls_url?(handle_ezproxy(rsrc.url)) and
          request.referent.metadata['genre'] != "book" and
            !request.get_service_type("fulltext", { :refresh => true }).empty?
        # We have our own list of URLs to suppress, array of strings
        # or regexps.
        next if @suppress_urls.find {|suppress| suppress === rsrc.url}
        urls_seen.push(rsrc.url)
        service_data = {}
        @rsrc_attributes.each do |attr|
          service_data[attr] = rsrc.method(attr).call
        end
        # Default display text to URL.
        service_data[:display_text] = (service_data[:display].nil?) ? service_data[:url] : service_data[:display]
        # Add the response
        request.add_service_response(
          service_data.merge(
            :service => self,
            :service_type_value => 'fulltext'
          )
        )
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
        request.add_service_response(
          service_data.merge(
            :service => self,
            :service_type_value => 'table_of_contents'
          )
        )
      end
    end
    if @service_types.include?("highlighted_link")
      # Let's find any related links, and add highlighted link responses for those.
      related_links_seen = [] # for de-duplicating urls from catalog.
      primo_searcher.related_links.each do |related_link|
        url = related_link.url # actual url
        next if related_links_seen.include?(related_link.url)
        # We have our own list of URLs to suppress, array of strings
        # or regexps.
        next if @suppress_related_links.find {|suppress| suppress === related_link.url}
        # No url? Forget it.
        next if related_link.url.nil?
        related_links_seen.push(related_link.url)
        service_data = {}
        @related_link_attributes.each do |attr|
          service_data[attr] = related_link.method(attr).call
        end
        # Default display text to URL.
        service_data[:display_text] = (service_data[:display].nil?) ? service_data[:url] : service_data[:display]
        # Add the response
        request.add_service_response(
          service_data.merge(
            :service => self,
            :service_type_value => 'highlighted_link'
          )
        )
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

  # Enhance the referent based on metadata in the given record
  def enhance_referent(request, record)
    @referent_enhancements.each do |key, options|
      metadata_element = (options[:value].nil?) ? key : options[:value]
      # Enhance the referent from the 'addata' section
      method = "addata_#{metadata_element}".to_sym
      # Get the metadata value if it's there
      metadata_value = record.send(method) if record.respond_to? method
      # Enhance the referent
      request.referent.enhance_referent(key.to_s, metadata_value,
        true, false, options) unless metadata_value.nil?
    end
  end
  private :enhance_referent

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
    return true unless (@primo_id.nil? or @primo_id.empty?)
    return true unless (@issn.nil? or @issn.empty?) and (@isbn.nil? or @isbn.empty?)
    return false if (record_metadata.nil? or record_metadata.empty? or record_metadata[:title].nil? or record_metadata[:title].empty?)
    # Titles must be equal
    return false unless record_metadata[:title].downcase.eql?(@title.downcase)
    # Compare record metadata with metadata that was passed in.
    # Only check if the record metadata value contains the input value since we can't be too strict.
    record_metadata.each { |type, value| return false if value.downcase.match("#{self.method(type).call}".downcase).nil?}
    return true
  end
  private :reliable_match?

  def config_file
    default_file = "#{Rails.root}/config/primo.yml"
    config_file = @primo_config.nil? ? default_file : "#{Rails.root}/config/"+ @primo_config
    Rails.logger.warn("Primo config file not found: #{config_file}.") and return {} unless File.exists?(config_file)
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