module Umlaut
  VERSION = "4.1.6"

  # This is used in Umlaut's .gemspec for generating the gem,
  # and is also used in the umlaut app generator to make sure
  # we're generating with a compatible Rails version. 
  RAILS_COMPAT_SPEC = [">= 3.2.12", "< 4.3.0"]
end
