# Settings specified here will take precedence over those in config/environment.rb

# The production environment is meant for finished, "live" apps.
# Code is not reloaded between requests
config.cache_classes = true
# Don't check view timestamps! This becomes uneccesary in Rails 2.2, and will
# probably raise there. 
config.action_view.cache_template_loading = true

# Use a different logger for distributed setups
# config.logger = SyslogLogger.new

# Full error reports are disabled and caching is turned on
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true

# Enable serving of images, stylesheets, and javascripts from an asset server
# config.action_controller.asset_host                  = "http://assets.example.com"

# Disable delivery errors, bad email addresses will be ignored
# config.action_mailer.raise_delivery_errors = false

################################
# Umlaut-specific choices:     #
################################

# Tell the buffered logger to actually buffer logging in production,
# for better efficiency. Not sure this actually works, I think Rails
# flushes it after every request anyway, but can't hurt. 

config.logger.auto_flushing = 30 if config.logger.methods.find{|m| m == 'auto_flushing='}

# Call particular environment-specific local umlaut environment-like file. 
path = File.join(RAILS_ROOT, "config", "umlaut_config", "environments", "production.rb")
if File.exists?( path )
    load path 
    umlaut_configuration( config )  if methods.find {|m| m == "umlaut_configuration"}
end

