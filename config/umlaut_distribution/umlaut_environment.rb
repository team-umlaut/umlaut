# Things that would ordinarily go in Rails config/environment.rb go
# in here for localized Umlaut configuration. (That is, config
# specific to your local installation, as opposed to config that
# all Umlaut installations need). 

# You have to restart Umlaut to pick up changes here. 

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
# RAILS_GEM_VERSION = '1.2.1' unless defined? RAILS_GEM_VERSION

# Instead of ordinary Rails way, we define this method that will be called for
# local config. 
def umlaut_configuration(config)
  
  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug
  
  # See Rails::Configuration for more Rails options. You can
  # put any Rails options here to over-ride Umlaut defaults. 

  # ---------------------------
  # Umlaut options
  # ----------------------------

  
  # Multi-thread action of foreground services.
  # Reccommend you leave set to true, unless debugging. 
  config.app_config.threaded_services = true 

  # Specify the name of a Rails layout to use for resolver
  # screens. Recommend that you put local layouts in
  # app/views/layouts/local/. See some included alternates
  # in app/views/layouts/distribution
  # config.app_config.resolve_layout = "local/my_local_layout"
  # config.app_config.resolve_layout = "distribution/jhu_resolve"

  # Specify name of layout for search controller, if you don't want
  # the default basic one. 
  # config.app_config.search_laytout = 'local/local_layout'

  # Are we using the Umlaut journal db system? jrochkind does not. Defaults
  # to true, but we're not sure it works, so best leave it false at the moment. 
  config.app_config.use_umlaut_journal_index = false

  # User displayable name of application, defaults to 'Find It'
  # config.app_config.app_name = 'Find It'
  # image to use for links to your link resolver? If not given,
  # text link will be used.
  # config.app_config.link_img_url = 'http://sfx.library.jhu.edu:8000/sfxmenu/sfxit/jhu_sfx.gif'
  # Base url to your main SFX instance. Only used in a few weird
  # places, like error recovery screen. Set if possible.
  # config.app_config.main_sfx_base_url = 'http://sfx.library.jhu.edu:8000/jhu_sfx?'

  # In really bad errors when we have nothing else to do, a help/reference
  # email for the user?
  #config.app_config.help_url = "http://mylibrary.edu/help"
  
  # Partial view to use for displaying holdings in default resolve view
  #   config.app_config.partial_for_holding = 'alternate/holding_alternate'

  # Use a whole new view for resolve view, eg
  #   config.app_config.resolve_view = "alternate/alt_holdings"
  #   config.app_config.resolve_view = "local/my_custom_holdings"

  # link_with_frameset can be used to control whether (and when)
  # umlaut links to resources in a frameset page with an umlaut banner.
  # See also skip_resolve_menu below 
  # Possible values:
  #
  #  true      : always link with banner
  #  false     : never link with banner
  #  :standard : standard behavior -- link with banner only if the umlaut
  #               menu was skipped for a direct link.
  #  Or, for most powerful flexibility, set to a lambda expression taking
  #  one argument. That argument will be a hash containing the key
  #  :service_type_join with a ServiceType value. lambda can examine
  #  that join (and it's Request), and return true or false to control
  #  whether that specific link should be presented with banner frameset. 
  #  eg., to just banner full text links: 
  #  config.app_config.link_with_frameset = 
  #    lambda {|args| return args[:service_type_join].service_type_value.name == 'fulltext' }
  config.app_config.link_with_frameset = :standard

  # skip_resolve_menu can be used to control 'direct' linking, skipping
  # the resolve menu to deliver a full text link or other resource
  # directly to the user. See also link_with_frameset above. 
  # Possible values:
  # false  : [default] Never skip menu
  #   A hash with one or more keys....
  # {:service_types => ['fulltext']} : list of service type values, if 
  #          they're present skip the menu with the first response available.
  # {:services => ['sfx_my_university'] : list of services; only use responses
  #          from listed service for skipping, if present. Service IDs as
  #          identified in services.yml
  # {:excluded_services => ['JH_HIP'] : list of service IDs, exclude responses
  #          from these services for direct linking. (Not yet implemented)
  # {:excluded_urls => [/regexp/, 'string'] : list of regexps or strings,
  #          exclude URLs that match this string from being skipped to. (Not yet implemented)
  # {:excluded_rfr_ids => ["info:sid/sfxit.com:citation", '"info:sid/umlaut.code4lib.org:citation"'] }
  # {:lambda => lambda {|args| return something}} : Not yet implemented. 
  
  # lambda expression: A lambda expression can be provided that
  #          should expect one argument, a hash with key :request
  #          and value the Umlaut Request object. Return nil to
  #          not skip menu, or a ServiceType join obj to skip
  #          menu to that response.

  # A pretty typical direct-linking setup:
  # config.skip_resolve_menu = {:service_types => ['fulltext']}

  # Minimum height and width of browser window. We have little control over
  # what size a content provider generates a window for a link resolver. Often
  # it's too small for umlaut. So we resize in js, if these config params
  # are given. 
  # config.app_config.minimum_window_width = 820
  # config.app_config.minimum_window_height = 530

  # Expire service responses. Service responses are only re-used by the same
  # session that generated them. But sometimes even that's too much, we
  # want to expire them eventually, say every 24 hours. 
  # You can do this in two ways.
  #
  # A Number of seconds in an interval, eg:
  # config.app_config.response_expire_interval = 1.day
  #
  # Or, sometimes it's convenient to synchronize this with some other
  # process that runs on crontab. Say, expire at midnight every night:
  # config.app_config.response_expire_crontab_format = "00 00 * * *"


  # Custom logic as to whether the ILL (doc_del) section of the resolve
  # menu should be shown. This sample logic is, I think, copied from rsinger's
  # original, not sure what motivates it. Used by default resolve view,
  # if you write a custom resolve view it would be nice to respect this
  # too. 
  # config.app_config.resolve_display_ill = lambda do |umlaut_request|
  #     return true if (umlaut_request.get_service_type('fulltext').empty? &&
  #                     umlaut_request.get_service_type('holding').empty?) ||
  #                     ( @umlaut_request.referent.format != 'journal' ) ||
  #                     ( ! @umlaut.request.referent.metadata['atitle'].empty? )
  #     return false
  #  end                      
    
end


