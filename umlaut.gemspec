$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "umlaut/version"

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
  s.test_files = Dir["./test/**/*"].reject do |f| 
    f =~ %r{^(\./)?test/dummy/log}
  end.reject do |f|
    f =~ %r{^(\./)?test/dummy/config/database[^ ]*\.yml}
  end
  
  s.add_dependency "rails", "~> 3.2.0"
  s.add_dependency "jquery-rails"         # our built in JS uses jquery
  
  s.add_dependency "nokogiri"             # for XML parsing
  s.add_dependency "openurl", ">= 0.3.0"  # for OpenURL parsing and creating
  s.add_dependency "marc", "~> 0.4.3"     # for parsing Marc files in catalog/ils adaptors
  s.add_dependency "isbn"                 # used by amazon among others
  s.add_dependency "htmlentities"         # used by SFX adapter to unescape &ent;s
  # Remember to generate a faster json adapter into app gemfile, rather than just multi_json lowest common denominator.
  s.add_dependency "multi_json"           # use best locally installed json gem for json parsing
  s.add_dependency "confstruct", "~> 0.2" # used for our configuration object
  s.add_dependency "soap4r-ruby1.9"       # for Primo Web Service calls
  s.add_dependency "httparty"             # for REST API calls

  # We don't actually use sqlite at all. 
  #s.add_development_dependency "sqlite3"
end
