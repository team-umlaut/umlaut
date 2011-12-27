
require 'rails/generators'

module Umlaut
  class ServiceConf < Rails::Generators::Base
    source_root File.join(Umlaut::Engine.root, "lib", "generators", "templates")

    
    
    def generate_service_conf_skeleton
      copy_file("umlaut_services.yml", "config/umlaut_services.yml")
    end
    
  end  
end
