require 'rails/generators'

module Umlaut
  class Install < Rails::Generators::Base
    source_root File.join(Umlaut::Engine.root)
            
    include ActionView::Helpers::TextHelper
    
    def no_class_reloading
      /^((\s*)config\.cache_classes +\= +false\s*)$/
      gsub_file("config/environments/development.rb", /^(\s*)config\.cache_classes +\= +false\s*$/) do |match|
        # for some reason we can't make access to $1 in here from the above
        # regexp work, so we need to match again
        match =~ /^(\s*)/        
        <<-EOS
#{$1}#
#{$1}# UMLAUT: Umlaut's use of threading is not compatible with class
#{$1}# reloading, even in development. Umlaut requires true here.
#{$1}# Rails 3.2 _might_ let you get away with false when it comes out.
#{$1}config.cache_classes = true
          EOS
      end
    end        
  
    def inject_blacklight_routes
      route("Umlaut::Routes.new(self).draw")
    end
    
    def generate_service_conf_skeleton
      copy_file("lib/generators/templates/umlaut_services.yml", "config/umlaut_services.yml")
    end
    
    def migrations
      rake("umlaut:install:migrations")
    end
    
    def asset_hooks
      generate("umlaut:asset_hooks")
    end
    
    def local_umlaut_controller
      copy_file("app/controllers/umlaut_controller.rb")
    end
      
    def post_install_message            
        say("\n              Umlaut installed, now:", :yellow)
        $stdout.puts(
          "              " +
          word_wrap("After setting up your 'development' database in config/databases.yml, run `rake db:migrate`", :line_width => 60).
            split("\n").
            join("\n              ")
          )
        
    end
  end  
end
