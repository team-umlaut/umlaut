# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../dummy/config/environment.rb",  __FILE__)
require "rails/test_help"

ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__) 

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# Complete stack trace with deprecation warnings from rails
ActiveSupport::Deprecation.debug = true

# Custom method for NYU-only tests. We still have a bunch of tests for aleph/
# primo that work against live nyu services and can only succeed if you are 
# nyu. Oops. We provide this convenience function to wrap test_* class
# method bodies for nyu only tests, so they'll only be run if
# ENV variable NYU_TEST is set, otherwise you'll get a little message
# and a fake test. 


# 'skip' only works in ruby 1.9.x, plus outputs a bunch of annoying stuff.
#, plus doesn't give NYU any good way to run em without editing 'skip' out
# of a buncha places. 

# nyu_only_test("AlephTests") do
#   def test_something
#     assert_something
#   end
#   def test_something_else
#     assert_else
#   end
# end
def nyu_only_tests(test_name="Some")

  run_tests = ENV['NYU_TEST'] || false
  
  unless run_tests
    warn("#{test_name} tests can't be run outside of NYU, skipping.")
    def test_nothing
      # avoid "no tests were specified" error. 
    end
  else
    yield
  end
end

