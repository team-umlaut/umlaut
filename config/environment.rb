# Be sure to restart your web server when you modify this file.

# Uncomment below to force Rails into production mode when 
# you don't control web/app server and can't set it the proper way
# ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '1.2.1' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

require 'plugins/app_config/lib/configuration'

ActiveRecord::Base.allow_concurrency = true

Rails::Initializer.run do |config|

  $KCODE = 'UTF8'

  # Settings in config/environments/* take precedence over those specified here
  
  # Skip frameworks you're not going to use (only works if using vendor/rails)
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Only load the plugins named here, by default all plugins in vendor/plugins are loaded
  # config.plugins = %W( exception_notification ssl_requirement )

  # Add additional load paths for your own custom dirs
  # config.load_paths += %W( #{RAILS_ROOT}/extras )

  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Use the database for sessions instead of the file system
  # (create the session table with 'rake db:sessions:create')
  # config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper, 
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  # See Rails::Configuration for more options

  
  # For ruby-debug
  SCRIPT_LINES__ = {} if ENV['RAILS_ENV'] == 'development'
  
  # Umlaut Configuration below. 
  
  # Multi-thread action of foreground services.
  # Reccommend you leave set to true, unless debugging. 
  config.app_config.threaded_services = true


  config.app_config.app_name = 'Find It'
    config.app_config.link_img_url = 'http://sfx.library.jhu.edu:8000/sfxmenu/sfxit/jhu_sfx.gif'
    config.app_config.main_sfx_base_url = 'http://sfx.library.jhu.edu:8000/jhu_sfx?'
  
    config.app_config.use_umlaut_journal_index = false
  
    config.app_config.resolve_layout = "local/jhu_resolve"
    config.app_config.search_layout = 'local/jhu_search'
  
    config.app_config.partial_for_holding = 'holding_alternate'
  
    config.app_config.skip_resolve_menu = {:service_types => ['fulltext']}
    config.app_config.link_with_frameset = :standard
    
    config.app_config.minimum_window_width = 820
    config.app_config.minimum_window_height = 350

    config.app_config.resolve_display_ill = lambda {|uml_request| return true}

    config.app_config.resolve_view = "alternate/resolve_alternate"

  
  # Load local config file
  local_env_path = "#{RAILS_ROOT}/local/config/environment.rb"
  load local_env_path if File.exists?( local_env_path )
end

# Add new inflection rules using the following format 
# (all these examples are active by default):
# Inflector.inflections do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
# Mime::Type.register "application/x-mobile", :mobile


