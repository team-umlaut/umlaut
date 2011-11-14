Umlaut::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  
  # umlaut needs cache classes even in development for threading. 
  config.cache_classes = true
  # other things for thread-safety
  #config.dependency_loading = false
  #config.preload_frameworks = true
  

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_view.debug_rjs             = true
  config.action_controller.perform_caching = false

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
  
  # turn off SQL traces for now
  config.after_initialize do
    ActiveRecord::Base.logger = Rails.logger.clone
    ActiveRecord::Base.logger.level = Logger::INFO
  end

  
end

