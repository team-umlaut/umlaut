require 'rails/generators'

module Umlaut
  class Install < Rails::Generators::Base
    source_root File.join(Umlaut::Engine.root)
    
    class_option :only, :type=>:array
    class_option :except, :type=>:array
            
    include ActionView::Helpers::TextHelper
    
    def config_cache_classes
      guarded(:config_cache_classes) do
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
    end
    
    def database_yml_hints
      guarded(:database_yml_hints) do
        insert_into_file("config/database.yml", :before => /^(\s*)development:/) do                     
          <<-eos
#
# UMLAUT: mysql db with mysql2 adapter strongly recommended for Umlaut, in both 
# production and development. sqlite3 has unclear semantics under threaded 
# concurrency which umlaut uses, and in many cases simply does not work. 
#
# A higher pool size than ordinary is recommended because of umlaut's
# use of concurrency. Perhaps as large as the number of services
# you have configured to run in the same wave, plus another few. 
#
# development:
#   adapter: mysql2
#   host: 
#   username:
#   password:
#   database:
#   pool: 15 

          eos
        end
        append_to_file("config/database.yml") do
          <<-eos
          
#
# UMLAUT: for the 'search' functions (A-Z title lookup) to work, you need
# a direct database connection to the SFX database, under 'sfx_db' key. 
# You should manually set up a new read-only MySQL account in the SFX db
# for this purpose, rather than use one of the full-access existing SFX
# mysql accounts. 
#
#sfx_db:
#  adapter: mysql2
#  host: my_sfx_host.u.edu
#  port: 3310 # 3310 is defualt SFX embedded mysql port
#  database: sfxlcl41 # or other sfx instance db
#  username:
#  password:
#  pool: 5
#  encoding: utf8
# 
          eos
        end
      end
    end
    
  
    def routes
      guarded(:routes) do
        route("Umlaut::Routes.new(self).draw")
      end
    end
    
    def umlaut_services_skeleton
      guarded(:umlaut_services_skeleton) do
        copy_file("lib/generators/templates/umlaut_services.yml", "config/umlaut_services.yml")
      end
    end
    
    def migrations
      guarded(:migrations) do
        rake("umlaut:install:migrations")
      end
    end
    
    def asset_hooks
      guarded(:asset_hooks) do
        generate("umlaut:asset_hooks")
      end
    end
    
    def local_umlaut_controller
      guarded(:local_umlaut_controller) do
        copy_file("app/controllers/umlaut_controller.rb")
      end
    end
      
    def post_install_message            
        say("\n              Umlaut installed, now:", :yellow)
        $stdout.puts(
          "              " +
          word_wrap("After setting up your 'development' database in config/databases.yml, run `rake db:migrate`", :line_width => 60).
            split("\n").
            join("\n              ") + "\n"
          )
        
    end
    
    no_tasks do
      def guarded(section, &block)
        if (options[:only].nil? || options[:only].include?(section.to_s)) &&
           (options[:except].nil? || ! options[:except].include?(section.to_s))
          yield
        else
          say_status("skipped", section.to_s, :blue)
        end
        
      end
    end
    
  end  
end
