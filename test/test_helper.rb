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

class ActiveSupport::TestCase
  def self.sfx4_fixtures(*fixture_names)
    sfx4s = ["Global", "Local"]
    sfx4s.each do |sfx4|
      # Get the db module associate with this sfx4 instance
      sfx4_module = Sfx4.const_get(sfx4.to_sym)
      # Get the connection from the :Base class for each sfx4
      # Set the path
      path = "#{File.dirname(__FILE__)}/fixtures/#{sfx4_module.to_s.underscore}"
      # Get class names hash of table_name => class_name
      class_names = {}
      connection = nil
      fixture_names.collect{|t|t.to_s}.each do |table| 
        next unless sfx4_module.const_defined?(table.classify)
        #Find class from table name
        klass = sfx4_module.const_get table.classify
        connection ||= klass.connection
        class_names[klass.table_name.downcase.to_sym] = klass.name
      end
      # Table names are just the keys of the class names
      table_names = class_names.keys.collect{|t| t.to_s}
      # Create and Instantiate Fixtures
      ActiveRecord::Fixtures.create_fixtures(path, table_names, class_names){connection}.first.fixtures
    end
  end
end

# VCR is used to 'record' HTTP interactions with
# third party services used in tests, and play em
# back. Useful for efficiency, also useful for
# testing code against API's that not everyone
# has access to -- the responses can be cached
# and re-used. 
require 'vcr'
require 'webmock'

# To allow us to do real HTTP requests in a VCR.turned_off, we
# have to tell webmock to let us. 
WebMock.allow_net_connect!

VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr_cassettes'
  # webmock needed for HTTPClient testing
  c.hook_into :webmock 
end

# Silly way to not have to rewrite all our tests if we
# temporarily disable VCR, make VCR.use_cassette a no-op
# instead of no-such-method. 
if ! defined? VCR
  module VCR
    def self.use_cassette(*args)
      yield
    end
  end
end

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

