require 'umlaut/routes'

# not sure why including openurl gem doesn't do the require, but it
# seems to need this. 
require 'openurl'
require 'bootstrap-sass'

module Umlaut
  class Engine < Rails::Engine
    engine_name "umlaut"
    
    # We need the update_html.js script to be available as it's own
    # JS file too, not just compiled into application.js, so we can
    # deliver it to external apps using it (JQuery Content Utility).
    # It will now be available from path /assets/umlaut/update_html.js
    # in production mode with precompiled assets, also in dev mode, 
    # whatevers.     
    initializer "#{engine_name}.asset_pipeline" do |app|
      app.config.assets.precompile << 'umlaut/update_html.js'
      app.config.assets.precompile << "umlaut_ui.js"
    end    
  end
end
