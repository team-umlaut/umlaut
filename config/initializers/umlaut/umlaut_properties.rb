  # Some miscelanous config. 
  # Includes some urls for local services, and labels used for display, identifying service and institution and such.

  # App name. 
  AppConfig::Base.app_name = 'Find It'

  # Sometimes Umlaut sends out email, what email addr should it be from?
  AppConfig::Base.from_email_addr = 'no_reply@umlaut.example.com'

  # rfr_ids used for umlaut generated pages.
  AppConfig::Base.rfr_ids ||= Hash.new
  AppConfig::Base.rfr_ids[:opensearch] = "info:sid/umlaut.code4lib.org:opensearch"
  AppConfig::Base.rfr_ids[:citation] = "info:sid/umlaut.code4lib.org:citation"
  AppConfig::Base.rfr_ids[:azlist] = 'info:sid/umlaut.code4lib.org:azlist'

  # img url to use for a link resolver link image.  
  #AppConfig::Base.link_img_url = 'http://sfx.library.jhu.edu:8000/sfxmenu/sfxit/jhu_sfx.gif'

  # base sfx url to use for search actions, error condition backup,
  # and some other purposes. For search actions (A-Z), direct database
  # connection to your SFX db also needs to be defined in database.yml
  #AppConfig::Base.main_sfx_base_url = 'http://sfx.library.jhu.edu:8000/jhu_sfx?'
  # 
  # Is your SFX database connection Sfx3 or Sfx4?
  #AppConfig::Base.az_search_method = SearchMethods::Sfx4
  #AppConfig::Base.az_search_method = SearchMethods::Sfx3  

  # help url used on error page and a few other places.
  #AppConfig::Base.help_url = "http://www.library.jhu.edu/services/askalib/index.html"

  # OpenSearch descriptions and names
  AppConfig::Base.opensearch_short_name = DependentConfig.new {"Find Journals with #{AppConfig::Base.app_name}"}
  AppConfig::Base.opensearch_description = DependentConfig.new {"Search #{AppConfig::Base.app_name} for journal names containing your term."}

  # Minimum height and width of browser window. We have little control over
  # what size a content provider generates a window for a link resolver. Often
  # it's too small for umlaut. So we resize in js, if these config params
  # are given. Set to 0 to disable. 
  AppConfig::Base.minimum_window_width = 820
  #AppConfig::Base.minimum_window_height = 0

  # Use your own custom search view? Stick in app/views/local and refer
  # to it here. 
  #AppConfig::Base.search_view = "local/my_search"
