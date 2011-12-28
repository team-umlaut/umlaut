
require 'rails/generators'

module Umlaut
  class UmlautControllerGenerator < Rails::Generators::Base
    source_root File.join(Umlaut::Engine.root)

    def local_umlaut_controller
      copy_file("app/controllers/umlaut_controller.rb")
    end
    
  end
end
