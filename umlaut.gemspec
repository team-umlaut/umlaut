$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "umlaut/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "umlaut"
  s.version     = Umlaut::VERSION
  s.authors     = ["Jonathan Rochkind, et al"]
  s.email       = ["umlaut-general@rubyforge.org"]
  s.homepage    = "https://github.com/team-umlaut/umlaut"
  s.summary     = "For Libraries, a just-in-time last-mile service aggregator, taking OpenURL input"
  #s.description = "TODO: Description of Umlaut."

  s.files = Dir["{app,config,db,lib,active_record_patch}/**/*"] + ["LICENSE", "Rakefile", "README.md"]
  s.test_files = Dir["./test/**/*"].reject do |f| 
    f =~ %r{^(\./)?test/dummy/log}
  end.reject do |f|
    f =~ %r{^(\./)?test/dummy/config/database[^ ]*\.yml}
  end
  
  s.add_dependency "rails", "~> 3.2.5"
  s.add_dependency "jquery-rails"         # our built in JS uses jquery
 
  # nokogiri needs to be on or greater than version 1.5.3: 
  # https://github.com/tenderlove/nokogiri/issues/638 
  s.add_dependency "nokogiri", "~>1.5.3"    # for XML parsing
  s.add_dependency "openurl", ">= 0.4.0"  # for OpenURL parsing and creating
  s.add_dependency "marc", ">= 0.5.0", "< 1.1"  # for parsing Marc files in catalog/ils adaptors
  s.add_dependency "isbn"                 # used by amazon among others
  s.add_dependency "htmlentities"         # used by SFX adapter to unescape &ent;s
  # Remember to generate a faster json adapter into app gemfile, rather than just multi_json lowest common denominator.
  s.add_dependency "multi_json"           # use best locally installed json gem for json parsing
  s.add_dependency "confstruct", "~> 0.2" # used for our configuration object
  s.add_dependency "exlibris-primo", "~> 1.0.4" # for Primo Service
  s.add_dependency "ensure_valid_encoding"      # used for correcting bad char enc bytes in input
  s.add_dependency "sass-rails"
  s.add_dependency "bootstrap-sass"
    
  s.add_development_dependency "single_test", "~> 0.5.1"
  s.add_development_dependency "uglifier"
  s.add_development_dependency "vcr"
  s.add_development_dependency "webmock"
  s.add_development_dependency "sunspot_rails" # add sunspot support
end
