require 'rails/generators'

module Umlaut
  class RemoveTurbolinks < Rails::Generators::Base

    def remove_turbolinks_js_reference
      gsub_file "app/assets/javascripts/application.js", /\/\/\= require ['"]?turbolinks['"]?\n?/, ''
    end

    def remove_turbolinks_gem
      gsub_file "Gemfile", /( *\# Turbolinks.*\n)? *gem ['"]turbolinks['"].*\n/, '', :verbose => true
    end
  end
end