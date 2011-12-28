require 'rails/generators'

module Umlaut
  class AssetHooks < Rails::Generators::Base
    
    def add_to_stylesheet_manifest
      unless IO.read("app/assets/stylesheets/application.css").include?('Umlaut')
        insert_into_file "app/assets/stylesheets/application.css", :after => "/*" do
          %q{ 
 * The base Umlaut styles:
 *= require 'umlaut'         
          }
        end
        append_to_file("app/assets/stylesheets/application.css") do
          %q{
          
  /* Umlaut needs a jquery-ui theme CSS. Here's an easy way to get one,
     you can replace with another theme. */
  @import url(http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.16/themes/ui-lightness/jquery-ui.css);
          }
        end
      else
        say_status("skipped", "Your application.css already references Umlaut", :yellow)
      end
    end
    
    
  end  
end
