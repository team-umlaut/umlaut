
require 'rails/generators'

module Umlaut
  class Routing < Rails::Generators::Base
    
    def inject_blacklight_routes
      route("Umlaut::Routes.new(self).draw")
    end
    
  end  
end
