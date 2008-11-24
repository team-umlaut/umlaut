# Umlaut implementors: You should not need to modify this file for local
# implementation. Local configuration goes in 
# config/umlaut_config/environment.rb instead.

# This file includes Umlaut defaults that are cross-installation, that
# are part of the app itself.

# You can over-ride anything here over in your local config. 


# Specifies gem version of Rails to use when vendor/rails is not present
# Umlaut was originally developed/tested with 1.2.1, but we've succesfully
# moved to 2.1.1.  2.2.2 coming soon. 
RAILS_GEM_VERSION = '2.1.2' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

# We are using an old-school json library, including it in plugins.
# It uses non-conventional path, so we need to manually include it.
# We really ought to update/test this to use a modern ruby json gem instead.
$LOAD_PATH.unshift "#{RAILS_ROOT}/vendor/plugins/ruby-json-1.1.2"

require 'plugins/app_config/lib/configuration'

Rails::Initializer.run do |config|

    # Set custom logging format, which we need our custom logger to
    # do.
    # for some reason manual require of active_support is neccesary to have
    # this work in ./script/console mode. I don't know why. 
    require 'active_support' 
    
    require_dependency 'umlaut_logger'
    severity_level = ActiveSupport::BufferedLogger.const_get(config.log_level.to_s.upcase)
    log_file = File.join(RAILS_ROOT, "log", "#{RAILS_ENV}.log")
    
    our_logger = UmlautLogger.new(log_file, severity_level)
    #our_logger.formatter
    our_logger.formatter = lambda do |severity_label, msg| 
      time_fmtd = Time.now.strftime("%d %b %H:%M:%S")
      preface = "[#{time_fmtd}] (pid:#{$$}) #{severity_label}: "
      # stick our preface AFTER any initial newlines                            
      msg =~ /^(\n+)[^\n]/
      index = $1 ? $1.length : 0
      return msg.insert(index, preface)
    end
    config.logger = our_logger

  config.after_initialize do
    # Turning on ActiveRecord concurrency is neccesary because we use threading
    # for Umlaut
    # In >1.2.1, this needs to be in an after_initialize block.
    # See http://toolmantim.com/article/2006/12/27/environments_and_the_rails_initialisation_process
    # Concurrency no longer needed once we go to Rails 2.2, but instead we need to make 
    # sure The AR connection pool size is big enough for us. 
    # 
    ActiveRecord::Base.allow_concurrency = true
    # Connection pool has to be at least as large as all threads we need.
    # It's hard to know exactly how big we need this to be, with all our bg
    # threads, but it should be pretty big, probably around as big as
    # how many services you have configured.
    # For now, let's stay on Rails 2.1.
    

    # Call local umlaut intializers
      Dir["#{RAILS_ROOT}/config/umlaut_config/initializers/**/*.rb"].sort.each do |initializer|
 	        load(initializer)
      end

    # Reset all our DependentConfigs. Cool!
    DependentConfig.permanently_reset_all
  end

  # Settings in config/environments/* take precedence over those specified here
  
  # Skip frameworks you're not going to use (only works if using vendor/rails)
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Only load the plugins named here, by default all plugins in vendor/plugins are loaded
  # config.plugins = %W( exception_notification ssl_requirement )

  # Umlaut adds additional load paths for certain custom dirs 
  config.load_paths += %W( #{RAILS_ROOT}/lib/referent_filters )
  config.load_paths += %W( #{RAILS_ROOT}/lib/service_adaptors )
  
  # Force all environments to use the same logger level 
  # (by default production uses :info, the others :debug)
  # config.log_level = :debug

  # Make Time.zone default to the specified zone, and make Active Record store time values
  # in the database in UTC, and return them converted to the specified local zone.
  # Run "rake -D time" for a list of tasks for finding time zone names. Comment line to use default local time.
  #config.time_zone = 'UTC'


  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper, 
  # like if you have constraints or database-specific column types
  # config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  # config.active_record.default_timezone = :utc
  
  # See Rails::Configuration for more options

  # Umlaut expects sesson store in active record. You can override
  # this in umlaut_config/environment.rb if you like, but some
  # automatic session management might not work. 
  config.action_controller.session_store = :active_record_store
  # TODO: Change session store to default rails 2.x cookies?
  # But right now we count on sessions in the DB so we can tell
  # when to remove old data.
  
  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random,
  # no regular words or you'll be exposed to dictionary attacks.
  #config.action_controller.session = {
  #  :session_key => '_rails212demo_session',
  #  :secret      => '000bdf8f4fedb875c589b83d4c791b1405690044dd58d0e5689a42e7c7ca2927f5bab8568c3d139bf5c1d7933f0a6fbb57e7664d6685c7cd9f1811819f4cf2d1'
  #}


  # Call local environment-like file for main environment
  path =  File.join(RAILS_ROOT, "config", "umlaut_config", "environment.rb")
  if File.exists?( path )
    load path 
    umlaut_configuration( config )
  end

end



  


