require 'rails/generators'

module Umlaut
  class Install < Rails::Generators::Base
    include ActionView::Helpers::TextHelper
    
    def install
      generate("umlaut:class_cache_conf")
      
      generate("umlaut:routing")
      
      generate("umlaut:service_conf")
      
      rake("umlaut:install:migrations")
      
      generate("umlaut:asset_hooks")
      
      generate("umlaut:umlaut_controller")
      
      say("              Umlaut installed, now:", :yellow)
      $stdout.puts(
        "              " +
        word_wrap("After setting up your 'development' database in config/databases.yml, run `rake db:migrate`", :line_width => 60).
          split("\n").
          join("\n              ")
        )
      
    end
  end  
end
