# meant to be included in _controllers_, to get an
# umlaut_config method as a class_attribute (avail on class, overrideable
# on instance), exposed as helper method too, 
# that has a Confstruct configuration object that starts out
# holding global config. (right now via a direct refernce to the global
# one). 

require 'confstruct'

module UmlautConfigurable
  extend ActiveSupport::Concern
  
  included do
    class_attribute :umlaut_config
    helper_method :umlaut_config
    self.umlaut_config = Confstruct::Configuration.new
  end
  
  
  
  
  
  # Call as UmlautConfigurable.set_default_configuration!(confstruct_obj)
  # to initialize
  def self.set_default_configuration!(configuration)
    configuration.configure do
      app_name 'Find It'
      # URL to image to use for link resolver, OR name of image asset in local app. 
      #link_img_url "http//something"
      
      # Sometimes Umlaut sends out email, what email addr should it be from?
      from_email_addr 'no_reply@umlaut.example.com'
          
      layout "umlaut"
      resolve_layout deferred! {|c| c.layout}    
      search_layout deferred! {|c| c.layout}
      
      # help url used on error page and a few other places.
      # help_url  "http://www.library.jhu.edu/services/askalib/index.html"
      
      # Minimum height and width of browser window. We have little control over
      # what size a content provider generates a window for a link resolver. Often
      # it's too small for umlaut. So we resize in js, if these config params
      # are given. Set to 0 to disable.
      # Sadly, only some browsers let us resize the browser window, so this
      # feature only works in some browsers. 
      minimum_window_width    820
      minimum_window_height   400
      
      
      # rfr_ids used for umlaut generated pages.
      rfr_ids do
        opensearch  "info:sid/umlaut.code4lib.org:opensearch"
        citation    "info:sid/umlaut.code4lib.org:citation"
        azlist      'info:sid/umlaut.code4lib.org:azlist'
      end
      
      # If you have a test umlaut set up at another location to stage/test
      # new features, link to it here, and a helper method in default
      # layout will provide a subtle debugging link to it in footer,
      # for current OpenURL. 
      # test_resolve_base "http://app01.mse.jhu.edu/umlaut_dev"
      
      opensearch_short_name deferred! {|c| "Find Journals with #{c.app_name}" }
      opensearch_description deferred! {|c| "Search #{c.app_name} for journal names containing your term"}
      
      
      
      # Referent filters. Sort of like SFX source parsers.
      # hash, key is regexp to match a sid, value is filter object
      # (see lib/referent_filters )        
      add_referent_filters!( :match => /.*/, :filter => DissertationCatch.new ) 
      
        
      # skip_resolve_menu can be used to control 'direct' linking, skipping
      # the resolve menu to deliver a full text link or other resource
      # directly to the user.
      # Possible values:
      # false  : [default] Never skip menu
      #   A hash with one or more keys....
      # {:service_types => ['fulltext']} : list of service type values, if 
      #          they're present skip the menu with the first response available.
      # {:excluded_services => ['JH_HIP'] : list of service IDs, exclude responses
      #          from these services for direct linking. (Not yet implemented)
      # {:excluded_urls => [/regexp/, 'string'] : list of regexps or strings,
      #          exclude URLs that match this string from being skipped to. (Not yet implemented)
      # {:excluded_rfr_ids => ["info:sid/sfxit.com:citation", '"info:sid/umlaut.code4lib.org:citation"'] }
      # {:lambda => lambda {|p, l| return something}} : Not yet implemented. 
      
      # lambda expression: A lambda expression can be provided that
      #          should expect one argument, a hash with key :request
      #          and value the Umlaut Request object. Return nil to
      #          not skip menu, or a ServiceType join obj to skip
      #          menu to that response.
    
      # A pretty typical direct-linking setup, excludes queries that come
      # from citation linker/azlist/opensearch from direct linking. 
      # AppConfig::Base.skip_resolve_menu = {:service_types => ['fulltext'],
      #:services=>['JH_SFX'], :excluded_rfr_ids => ["info:sid/sfxit.com:citation",
      #'info:sid/umlaut.code4lib.org:citation',
      #'info:sid/umlaut.code4lib.org:azlist',  
      #'info:sid/umlaut.code4lib.org:opensearch']}
      #
      # "umlaut.skip_resolve_menu" paramter can also be passed in per-request, with
      # 'true' or shortname of a service type. 
      skip_resolve_menu false
      
      # How many seconds between updates of the background updater for background
      # services?
      poll_wait_seconds 4
      
      # if a background service hasn't returned in this many seconds, consider
      # it failed. (May actually be slow, more likely raised an exception and
      # our exception handling failed to note it as failed.)    
      background_service_timeout 30
      # If a service has status FailedTemporary, and it's older than a
      # certain value, it will be re-queued in #serviceDispatch.
      # This value defaults to 10 times background_service_timeout,
      # but can be set in app config variable requeue_failedtemporary_services
      # If you set it too low, you can wind up with a request that never completes,
      # as it constantly re-queues a service which constantly fails.
      requeue_failedtemporary_services_in deferred! {|c| c.background_service_timeout * 10}
  
      # custom view template for resolve#index
      resolve_view nil
      
      # If OpenURL came from manual entry of title/ISSN, and no match is found in
      # link resolver knowledge base, display a warning to the user of potential
      # typo?
      entry_not_in_kb_warning true
          
      nightly_maintenance do
         # When nightly_maintenance will expire sessions. Default to
         # 1 day. Over-ride locally if desired, but
         # probably no reason to.
        session_expire_seconds  1.day           
        referent_expire_seconds deferred! {|c| c.session_expire_seconds }
        
        
        # Expire service responses. Service responses are only re-used by the same
        # session that generated them. But sometimes even that's too much, we
        # want to expire them eventually, say every 24 hours. 
        # You can do this in two ways.
        #
        # A Number of seconds in an interval, eg:
        response_expire_interval  1.day
        #
        # Or, sometimes it's convenient to synchronize this with some other
        # process that runs on crontab. Say, expire at midnight every night:
        # response_expire_crontab_format  "00 00 * * *"
  
      end
      
      
      search do
        # Is your SFX database connection, defined in database.yml under
        # sfx_db and used for A-Z searches, Sfx3 or Sfx4?  Other SearchMethods
        # in addition to SFX direct db may be provided later. 
        az_search_method  SearchMethods::Sfx4
        #az_search_method  SearchMethods::Sfx3
        
        # When talking directly to the SFX A-Z list database, you may
        # need to set this, if you have multiple A-Z profiles configured
        # and don't want to use the 'default.
        sfx_az_profile "default"    
        
        # Use your own custom search view? mention it here.   
        #search_view = "my_search"
        
        # can set to "_blank" etc. 
        result_link_target nil
        
      end
      
      # config only relevant to SFX use  
      sfx do
        # was: 'main_sfx_base_url'
        # base sfx url to use for search actions, error condition backup,
        # and some other purposes. For search actions (A-Z), direct database
        # connection to your SFX db also needs to be defined in database.yml
        # sfx_base_url  'http://sfx.library.jhu.edu:8000/jhu_sfx?'
        # 
  
        
        
        # Umlaut tries to figure out from the SFX knowledge base
        # which hosts are "SFX controlled", to avoid duplicating SFX
        # urls with urls from catalog. But sometimes it misses some, or
        # alternate hostnames for some. Regexps matching against
        # urls can be included here. Eg,
        # AppConfig::Base.additional_sfx_controlled_urls = [
        #    %r{^http://([^\.]\.)*pubmedcentral\.com}
        #  ]    
        additional_sfx_controlled_urls = []
        
        # "web.archive.org" is listed in SFX, but that causes suppression
        # of MARC 856 tags from our catalog pointing to archive.org, which are
        # being used for some digitized books. We'd like to ignore that archive.org
        # is in SFX. Same for netlibrary.
        sfx_load_ignore_hosts = [/.*\.archive\.org/, /www\.netlibrary\.com/, 'www.loc.gov']
        
      end
    
      # Output timing of service execution to logs
      log_service_timing = true if Rails.env == "development"
      
      
      #####
      # Pieces of content on a Resolve page can be declaritively configured. 
      # Here are the defaults. You can add new elements to the resolve_sections
      # array in config and modify or delete existing resolve_sections elements.
      #
      # Look in comments at top of SectionRenderer class for what the keys
      # in each entry mean. 
      add_resolve_sections! do
        div_id "cover_image"
        partial "cover_image"
        visibility :responses_exist
        show_heading false
        show_spinner false
      end
      
      add_resolve_sections! do
        div_id "search_inside"
        html_area :resource_info
        partial "search_inside"
        show_partial_only true
      end
      
      add_resolve_sections! do
        div_id "fulltext"
        section_title "#{ServiceTypeValue[:fulltext].display_name} via:"
        html_area :main
        partial :fulltext
        show_partial_only true
      end
      
      add_resolve_sections! do
        div_id "excerpts"
        section_prompt "A limited preview which may include table of contents, index, and other selected pages."
        html_area :main
        list_visible_limit 5
        visibility :responses_exist
      end
      
      add_resolve_sections! do
        div_id "audio"
        section_title "#{ServiceTypeValue[:audio].display_name} via"
        html_area :main
        visibility :responses_exist
      end
      
      add_resolve_sections! do
        div_id :holding
        section_title ServiceTypeValue[:holding].display_name_pluralize
        html_area :main
        partial 'holding'
        service_type_values ["holding","holding_search"]
      end
      
      add_resolve_sections! do
        div_id "document_delivery"
        section_title "Request a copy from Inter-Library Loan"
        html_area :main
        visibility :responses_exist
        bg_update false
      end
      
      add_resolve_sections! do
        div_id "table_of_contents"
        html_area :main
        visibility :responses_exist
      end
      
      add_resolve_sections! do
        div_id "abstract"
        html_area :main
        visibility :responses_exist
      end
      
      add_resolve_sections! do
        div_id "help"
        html_area :sidebar
        bg_update false
        partial "help"
        show_heading false
        show_spinner false
        visiblity :responses_exist 
      end
      
      add_resolve_sections! do
        div_id "coins"
        html_area :sidebar
        partial "coins"
        service_type_values []
        show_heading false
        show_spinner false
        bg_update false
        partial_html_api false
      end
      
      add_resolve_sections! do
        div_id "export_citation"
        html_area :sidebar
        visiblity :in_progress
        item_name_plural "Export tools"
      end
      
      add_resolve_sections! do
        div_id "related_items"
        html_area :sidebar
        partial "related_items"
        section_title "More like this"
        item_name_plural "Related Items"
        # custom visibility, show it for item-level cites,
        # or if we actually have some
        visibility(  lambda do |renderer|
                        (! renderer.request.title_level_citation?) ||
                        (! renderer.responses_empty?)
                      end )
        service_type_values ['cited_by', 'similar']
      end
      
      add_resolve_sections! do
        div_id "highlighted_link"
        section_title "See also"
        html_area :sidebar
        visibility :in_progress
        partial_locals( :show_source => true )
      end
      
      add_resolve_sections! do
        div_id "service_errors"
        partial "service_errors"
        html_area :service_errors
        service_type_values []
      end
      
    end
  end
  
  
  
end
