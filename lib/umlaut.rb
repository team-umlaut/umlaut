require 'umlaut/routes'

# not sure why including openurl gem doesn't do the require, but it
# seems to need this. 
require 'openurl'
require 'sunspot_rails'

module Umlaut
  class Engine < Rails::Engine
    engine_name "umlaut"
    
    # we store some things in non-standard subdirs, add em to path.
    #
    # We EAGER load em all to try and handle threading issues. 
    
    config.autoload_paths << File.join(self.root, "lib", "referent_filters")
    config.eager_load_paths << File.join(self.root, "lib", "referent_filters")
    
    config.autoload_paths << File.join(self.root, "lib", "service_adaptors")
    config.eager_load_paths << File.join(self.root, "lib", "service_adaptors")
    
    # Ane make 'lib' dir auto-loaded, because we have legacy Rails2 code
    # that assumes it.
    config.autoload_paths << File.join(self.root, "lib")
    # Sadly including eager_load_paths here makes weird things happen, apparently
    # I don't entirely understand what's going on. 
    #config.eager_load_paths << File.join(self.root, "lib")
    
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
    
    # Patch with fixed 'fair' version of ConnectionPool, see 
    # active_record_patch/connection_pool.rb
    #initializer("#{engine_name}.patch_connection_pool", :before => "active_record.initialize_database") do |app|
      load File.join(self.root, "active_record_patch", "connection_pool.rb")
    #end
    
         
    
    
  end
end
