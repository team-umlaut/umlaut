require 'rails/generators'

module Umlaut
  class ClassCacheConf < Rails::Generators::Base
    
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
    
  end  
end
