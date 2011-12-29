$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "umlaut/version"
require 'rake'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "umlaut"
  s.version     = Umlaut::VERSION
  s.authors     = ["Jonathan Rochkind, et al"]
  s.email       = ["umlaut-general@rubyforge.org"]
  s.homepage    = "https://github.com/team-umlaut/umlaut/tree/umlaut3dev"
  s.summary     = "For Libraries, a just-in-time last-mile service aggregator, taking OpenURL input"
  #s.description = "TODO: Description of Umlaut."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["LICENSE", "Rakefile", "README.md"]
  s.test_files = Rake::FileList["./test/**/*"].exclude(%r{^test/dummy/log})

  s.add_dependency "rails", "~> 3.1.3"
  s.add_dependency "jquery-rails"         # our built in JS uses jquery
  
  s.add_dependency "nokogiri"             # for XML parsing
  s.add_dependency "openurl", ">= 0.2.0"  # for OpenURL parsing and creating
  s.add_dependency "marc", "~> 0.4.3"     # for parsing Marc files in catalog/ils adaptors
  s.add_dependency "isbn"                 # used by amazon among others
  s.add_dependency "htmlentities"         # used by SFX adapter to unescape &ent;s
  # Remember to generate a faster json adapter into app gemfile, rather than just multi_json lowest common denominator.
  s.add_dependency "multi_json"           # use best locally installed json gem for json parsing
  s.add_dependency "confstruct", "~> 0.2" # used for our configuration object

  # We don't actually use sqlite at all. 
  #s.add_development_dependency "sqlite3"
end
