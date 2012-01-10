require 'rails/generators'

module Umlaut
  class AssetHooks < Rails::Generators::Base
    
    def add_to_stylesheet_manifest
      existing = IO.read("app/assets/stylesheets/application.css")
      unless existing.include?('Umlaut')
        after = 
          if existing.include?("require_self")
            "require_self"
          else
            "/*"
          end
          
        insert_into_file "app/assets/stylesheets/application.css", :after => after do
          %q{ 
 *         
 * The base Umlaut styles:
 *= require 'umlaut'
 *}
        end
        append_to_file("app/assets/stylesheets/application.css") do
          %q{
          
  /* Umlaut needs a jquery-ui theme CSS. Here's an easy way to get one,
     you can replace with another theme. */
  @import url(//ajax.googleapis.com/ajax/libs/jqueryui/1.8.16/themes/ui-lightness/jquery-ui.css);
          }
        end
      else
        say_status("skipped", "Your application.css already references Umlaut", :yellow)
      end
    end
    
    def add_to_javascript_manifest
      unless IO.read("app/assets/javascripts/application.js").include?('Umlaut')
        prepend_to_file "app/assets/javascripts/application.js" do
          %q{
 // Umlaut javascript required for proper functionality. The 'umlaut' file
 // also forces require of jquery and jquery-ui, dependencies. 
 //= require 'umlaut'          
          }           
        end
      else
        say_status("skipped", "Your application.js already references Umlaut", :yellow)
      end
        
    end
    
    
  end  
end
