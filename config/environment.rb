# Umlaut implementors: You should not need to modify this file for local
# implementation. Local configuration goes in 
# config/umlaut_config/environment.rb instead.

# This file includes Umlaut defaults that are cross-installation, that
# are part of the app itself.

# You can over-ride anything here over in your local config. 



# Specifies gem version of Rails to use when vendor/rails is not present
# Umlaut was originally developed/tested with 1.2.1, but we've succesfully
# moved to 1.2.6. 
# 1.2.6  
RAILS_GEM_VERSION = '1.2.1' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

# We are using an old-school json library, including it in plugins.
# It uses non-conventional path, so we need to manually include it.
# We really ought to update/test this to use a modern ruby json gem instead.
$LOAD_PATH.unshift "#{RAILS_ROOT}/vendor/plugins/ruby-json-1.1.2"

require 'plugins/app_config/lib/configuration'

Rails::Initializer.run do |config|

  # Turning on ActiveRecord concurrency is neccesary because we use threading
  # for Umlaut
  # In >1.2.1, this needs to be in an after_config block.
  # See http://toolmantim.com/article/2006/12/27/environments_and_the_rails_initialisation_process  
  config.after_initialize do
    # And to keep db password from showing up in log, we need to trick the logger. Weird, sorry.
    orig_logger = ActiveRecord::Base.logger 
    ActiveRecord::Base.logger = nil

    ActiveRecord::Base.allow_concurrency = true

    ActiveRecord::Base.logger = orig_logger

    # sync institutions.yml to db if needed by timestamp.
    begin
      Institution.sync_institutions
      ServiceTypeValue.load_values
    rescue Exception => e
      # If we're just starting out and don't have a db yet, we can't run
      # this, oh well.
      RAILS_DEFAULT_LOGGER.warn("Couldn't check institutions and service_type_values for syncing: #{e}")
    end

    # Referent filters. Sort of like SFX source parsers.
    # hash, key is regexp to match a sid, value is filter object
    # (see lib/referent_filters )
    # We are in after_initialize block to take advantage of reset load path.
    # need to use AppConfig weird because of that. 
    AppConfig::Base.referent_filters = {/.*/, DissertationCatch.new  }

    # Call local config file. In after initialize for convenience
    # and ability to override defaults
    local_env_path = "#{RAILS_ROOT}/config/umlaut_config/environment.rb"
    if File.exists?( local_env_path )
      load local_env_path 
      umlaut_configuration( config )
    end
  
    # Some more defaults based on what they may have already set
    config.app_config.opensearch_short_name = "Find Journals with #{config.app_config.app_name}"
    config.app_config.opensearch_description = "Search #{config.app_config.app_name} for journal names containing your term."
    
  end

  $KCODE = 'UTF8'

  # Settings in config/environments/* take precedence over those specified here
  
  # Skip frameworks you're not going to use (only works if using vendor/rails)
  # config.frameworks -= [ :action_web_service, :action_mailer ]

  # Only load the plugins named here, by default all plugins in vendor/plugins are loaded
  # config.plugins = %W( exception_notification ssl_requirement )

  # Add additional load paths for your own custom dirs
  # Umlaut does. 
  config.load_paths += %W( #{RAILS_ROOT}/lib/referent_filters )

  
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

  # Umlaut expects sesson store in active record. You can override
  # this in umlaut_config/environment.rb if you like, but some
  # automatic session management might not work. 
  config.action_controller.session_store = :active_record_store 


  # Umlaut Configuration below.

  # When nightly_maintenance will expire sessions. Default to
  # 1 day. Over-ride in umlaut_config/environment.rb if desired, but
  # probably no reason to.
  # Can't use active support in environment.rb anymore. grr.
  #config.app_config.session_expire_seconds = 1.day
  config.app_config.session_expire_seconds = 1 * 60 * 60 * 24
  
  # Multi-thread action of foreground services.
  # Reccommend you leave set to true, unless debugging. 
  config.app_config.threaded_services = true

  #default
  config.app_config.app_name = 'Find It'
  
  #config.app_config.link_img_url = 'http://sfx.library.jhu.edu:8000/sfxmenu/sfxit/jhu_sfx.gif'
  #config.app_config.main_sfx_base_url = 'http://sfx.library.jhu.edu:8000/jhu_sfx?'
  
  #config.app_config.use_umlaut_journal_index = false
  
  #config.app_config.resolve_layout = "distribution/jhu_resolve"
  #config.app_config.search_layout = 'distribution/jhu_search'
  
  #config.app_config.partial_for_holding = 'alternate/holding_alternate'
  
  #config.app_config.skip_resolve_menu = {:service_types => ['fulltext']}
  config.app_config.link_with_frameset = :standard
    
  #config.app_config.minimum_window_width = 820
  #config.app_config.minimum_window_height = 350

  #config.app_config.resolve_display_ill = lambda {|uml_request| return true}

  #config.app_config.resolve_view = "alternate/resolve_alternate"

  # rfr_ids used for umlaut generated pages.
  config.app_config.rfr_ids ||= Hash.new
  config.app_config.rfr_ids[:opensearch] = "info:sid/umlaut.code4lib.org:opensearch"
  config.app_config.rfr_ids[:citation] = "info:sid/umlaut.code4lib.org:citation"
  config.app_config.rfr_ids[:azlist] = 'info:sid/umlaut.code4lib.org:azlist'



  
  # SFX Targets and other urls that we know have a problem with
  # being put in a frameset, and exclude from direct linking
  # in frameset. Some escape the frameset with javascript,
  # others run into problems with cookies in a frameset
  # environment.
  config.app_config.frameset_problem_targets = { :sfx_targets => [], :urls => [] }
  # Two lists, one that match SFX target names, another that match actual
  # destination urls. Either can be a string (for exact match) or a REGEXP. 
  config.app_config.frameset_problem_targets[:sfx_targets] = [
       /^WILSON\_/,
        'SAGE_COMPLETE',
      # HIGHWIRE_PRESS_FREE is a collection of different hosts,
      # but MANY of them seem to be frame-escapers, so we black list them all!
      # Seems to be true of HIGHWIRE_PRESS stuff in general in fact, they're
      # all blacklisted.
        /^HIGHWIRE_PRESS/,
        /^OXFORD_UNIVERSITY_PRESS/,
      # Springer (METAPRESS and SPRINGER_LINK) has a weird system requiring
      # cookies to get to a full text link. The cookies don't like the frameset
      #, so it ends up not working in frameset on some computers, somewhat hard 
      # to reproduce.
        /^METAPRESS/,
        /^SPRINGER_LINK/,
      # Cookie/frameset issue. Reproducible on IE7, not on Firefox. 
        /^WILEY_INTERSCIENCE/,
      # Mysterious problem in frameset but not direct link, in IE only.
      # Assume cookie problem. Could be wrong, very very low reproducibilty.
       'LAWRENCE_ERLBAUM_ASSOCIATES_LEA_ONLINE',
      # This one is mysterious too, seems to effect even non-frameset
      # linking sometimes? Don't understand it, but guessing cookie
      # frameset issue.
      'INFORMAWORLD_JOURNALS'
      ]

    # note that these will sometimes be proxied urls!
    # So we don't left-anchor the regexp. 
    config.app_config.frameset_problem_targets[:urls] = [
       /http\:\/\/www.bmj.com/,
       /http\:\/\/bmj.bmjjournals.com/, 
       /http\:\/\/www.sciencemag.org/,
       /http\:\/\/([^.]+\.)\.ahajournals\.org/,
       /http\:\/\/www\.circresaha\.org/,
       /http\:\/\/www.businessweek\.com/,
       /endocrinology-journals\.org/,
       /imf\.org/,
       # Weird hard to reproduce cookie issue
       /www\.ipap\.jp/
      ]

end

# Fix up Rails really annoying logging with our own monkey patching.
# This needs to be at end of file, not beginning! 
class Logger
  def format_message(severity, timestamp, progname, msg)
    time_fmtd = timestamp.strftime("%d %b %H:%M:%S")
    preface = "[#{time_fmtd}] (pid:#{$$}) #{severity}: "
    # stick our preface AFTER any initial newlines                            
    msg =~ /^(\n+)[^\n]/
    index = $1 ? $1.length : 0

    return "#{msg.insert(index, preface )}\n"
  end
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


