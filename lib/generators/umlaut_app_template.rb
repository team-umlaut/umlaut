# An app template to set up a Rails app with umlaut, with required
# configuration and generated content. 

# ENV['UMLAUT_GEM_PATH'] can be used to add the line to Gemfile
# with a path to local checkout of Umlaut. NOTE WELL the path
# passed in ENV must be absolute path OR relative to the generated
# app's gemfile (which is confusing). (We've already lost the actual
# CWD by the the time the generator runs, so we can't correct to relative
# to original command CWD)
# 

# Add the lib path from the copy of Umlaut we're in to the load path. 
# Since we're an app template, our gem isn't loaded yet. 
umlaut_lib = File.expand_path(File.dirname(__FILE__) + '/../')
$LOAD_PATH.unshift(umlaut_lib) if File.directory?(umlaut_lib) && !$LOAD_PATH.include?(umlaut_lib)

require 'umlaut/version'

umlaut_version = Umlaut::VERSION.split(".")

gem_spec_str = 
  "\ngem 'umlaut', '>= #{Umlaut::VERSION}', '< #{umlaut_version.first.to_i + 1}'"
if ENV["UMLAUT_GEM_PATH"]
  path = File.expand_path( ENV["UMLAUT_GEM_PATH"] )
  gem_spec_str += ", :path => '#{path}'"
end


append_file "Gemfile", gem_spec_str

generate "umlaut:remove_turbolinks"

generate "umlaut:install"
  
# future rails will offer an after_bundle hook we could use for
# a post-install message. Instead, the post-install message for now
# is in the `umlaut` command wrapper. 