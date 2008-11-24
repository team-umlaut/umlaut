  # Multi-thread action of foreground services.
  # Reccommend you leave set to true, unless debugging. 
  AppConfig::Base.threaded_services = true
    
  # Custom logic as to whether the ILL (doc_del) section of the resolve
  # menu should be shown. This sample logic is, I think, copied from rsinger's
  # original, not sure what motivates it. 
  # AppConfig::Base.resolve_display_ill = lambda do |umlaut_request|
  #     return true if (umlaut_request.get_service_type('fulltext').empty? &&
  #                     umlaut_request.get_service_type('holding').empty?) ||
  #                     ( @umlaut_request.referent.format != 'journal' ) ||
  #                     ( ! @umlaut.request.referent.metadata['atitle'].empty? )
  #     return false
  #  end
  # Below: Just always display it, if it's supplied by SFX. 
  AppConfig::Base.resolve_display_ill = lambda {|umlaut_request| return true}

  
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
  #  AppConfig::Base.link_with_frameset = 
  #    lambda {|args| return args[:service_type_join].service_type_value.name == 'fulltext' }
  AppConfig::Base.link_with_frameset = :standard

  # skip_resolve_menu can be used to control 'direct' linking, skipping
  # the resolve menu to deliver a full text link or other resource
  # directly to the user. See also link_with_frameset above. 
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
  AppConfig::Base.skip_resolve_menu = {:service_types => ['fulltext'], :services=>['JH_SFX'], :excluded_rfr_ids => ["info:sid/sfxit.com:citation", 'info:sid/umlaut.code4lib.org:citation', 'info:sid/umlaut.code4lib.org:azlist',
  'info:sid/umlaut.code4lib.org:opensearch']}


  # When nightly_maintenance will expire sessions. Default to
  # 1 day. Over-ride locally if desired, but
  # probably no reason to.
  AppConfig::Base.session_expire_seconds = 1.day

