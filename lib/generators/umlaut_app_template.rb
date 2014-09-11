# Add the lib path from the copy of Umlaut we're in to the load path. 
# Since we're an app template, our gem isn't loaded yet. 
umlaut_lib = File.expand_path(File.dirname(__FILE__) + '/../')
$LOAD_PATH.unshift(umlaut_lib) if File.directory?(umlaut_lib) && !$LOAD_PATH.include?(umlaut_lib)

require 'umlaut/version'

umlaut_version = Umlaut::VERSION.split(".")


gem_spec_str = 
  "\ngem 'umlaut', '>= #{Umlaut::VERSION}', '< #{umlaut_version.first.to_i + 1}'"

append_file "Gemfile", gem_spec_str

generate "umlaut:install"
  
# future rails will offer an after_bundle hook we could use for
# a post-install message. Instead, the post-install message for now
# is in the `umlaut` command wrapper. 