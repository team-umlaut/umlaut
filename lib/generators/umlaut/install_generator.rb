require 'rails/generators'

module Umlaut
  class Install < Rails::Generators::Base
    def install
      generate("umlaut:class_cache_conf")
      
      generate("umlaut:routing")
      
      generate("umlaut:service_conf")
      
      rake("umlaut:install:migrations")      
    end
  end  
end
