  # Multi-thread action of foreground services.
  # Reccommend you leave set to true, unless debugging. 
  AppConfig::Base.threaded_services = true
    


  #   Direct-link-with-frameset was an interesting experiment, but in jrochkind
  #   and JHU's experience/analysis, it is not reliable and consistent enough
  #   to actually use. We are no longer using it, and do not recommend
  #   the use of link_with_frameset or skip_resolve_menu any longer.  
  #
  
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
  # AppConfig::Base.skip_resolve_menu = {:service_types => ['fulltext'],
  #:services=>['JH_SFX'], :excluded_rfr_ids => ["info:sid/sfxit.com:citation",
  #'info:sid/umlaut.code4lib.org:citation',
  #'info:sid/umlaut.code4lib.org:azlist',  
  #'info:sid/umlaut.code4lib.org:opensearch']}
  AppConfig::Base.skip_resolve_menu = false


  # When nightly_maintenance will expire sessions. Default to
  # 1 day. Over-ride locally if desired, but
  # probably no reason to.
  AppConfig::Base.session_expire_seconds = 1.day

  # Umlaut tries to figure out from the SFX knowledge base
  # which hosts are "SFX controlled", to avoid duplicating SFX
  # urls with urls from catalog. But sometimes it misses some, or
  # alternate hostnames for some. Regexps matching against
  # urls can be included here. Eg,
  # AppConfig::Base.additional_sfx_controlled_urls = [
  #    %r{^http://([^\.]\.)*pubmedcentral\.com}
  #  ]
  AppConfig::Base.additional_sfx_controlled_urls = []
  
  
  # "web.archive.org" is listed in SFX, but that causes suppression
  # of MARC 856 tags from our catalog pointing to archive.org, which are
  # being used for some digitized books. We'd like to ignore that archive.org
  # is in SFX. Same for netlibrary.
  AppConfig.sfx_load_ignore_hosts = [/.*\.archive\.org/, /www\.netlibrary\.com/, 'www.loc.gov']
  
  
  
  # Custom logic as to whether the ILL (doc_del) section of the resolve
  # menu should be shown. This sample logic is, I think, copied from rsinger's
  # original, not sure what motivates it. 
  # AppConfig.resolve_display_ill = lambda do |umlaut_request|
  #     return true if (umlaut_request.get_service_type('fulltext').empty? &&
  #                     umlaut_request.get_service_type('holding').empty?) ||
  #                     ( @umlaut_request.referent.format != 'journal' ) ||
  #                     ( ! @umlaut.request.referent.metadata['atitle'].empty? )
  #     return false
  #  end
  # Or just always display it, if it's supplied by SFX. 
  AppConfig.resolve_display_ill = lambda {|umlaut_request| return true}
