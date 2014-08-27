ENV["RAILS_ENV"] ||= "test"

require File.expand_path('../dummy/config/environment', __FILE__)
#require 'engine_cart'
#EngineCart.load_application!

require 'rails/test_help'
require 'minitest/unit'

require 'coveralls'
Coveralls.wear!


ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__) 

Rails.backtrace_cleaner.remove_silencers!

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

# Complete stack trace with deprecation warnings from rails
ActiveSupport::Deprecation.debug = true
#ActiveSupport::Deprecation.silenced = true

# Fix stack traces to include Umlaut source lines
#Rails.backtrace_cleaner.remove_silencers!
#app_dirs_pattern = /^\/?(app|config|lib|test)/
#Rails.backtrace_cleaner.add_silencer do |line|
#  require 'debugger'
#  debugger if line =~ /umlaut/
#  line =~ app_dirs_pattern 
#end

require 'collection'
Collection.forward_background_exceptions = true

class ActiveSupport::TestCase
  ActiveRecord::Migration.check_pending!

  # Load SFX 4 fixtures only if we are explicitly creating a mock_instance
  # which should really only be the case for travis-ci.org
  def self.sfx4_fixtures(*fixture_names)
    # Load SFX 4 fixtures only if we are explicitly creating a mock_instance
    # which should really only be the case for travis-ci.org
    if (sfx4_mock_instance?)
      warn "Loading SFX4 fixtures."
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
        table_names = class_names.keys.collect{|t| t.to_s.upcase}
        # Create and Instantiate Fixtures
        ActiveRecord::FixtureSet.create_fixtures(path, table_names, class_names){connection}.first.fixtures
      end
    else
      warn  "Skipping SFX4 fixtures since the SFX DB specified is not a mock instance."
    end
  end
  
  def self.sfx4_mock_instance?
    (Sfx4::Local::Base.connection_configured? and
      Sfx4::Local::Base.connection_config[:mock_instance] and 
        Sfx4::Global::Base.connection_configured? and
          Sfx4::Global::Base.connection_config[:mock_instance])
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

without_ctx_tim = VCR.request_matchers.uri_without_param(:ctx_tim)
VCR.configure do |c|
  c.cassette_library_dir = 'test/vcr_cassettes'
  # webmock needed for HTTPClient testing
  c.hook_into :webmock 
  c.register_request_matcher(:uri_without_ctx_tim, &without_ctx_tim)
  # c.debug_logger = $stderr
  c.filter_sensitive_data("BX_TOKEN") { ENV['BX_TOKEN'] } unless ENV['BX_TOKEN'].blank?
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

def assert_length(size, list)
  assert_equal size, list.length, "Expected size of #{size} for #{list}"
end

# We want to put assert_present and assert_blank back, they were
# useful, why did minitest deprecate it?
module ActiveSupport::Testing::Assertions
  def assert_present(object, message=nil)
    message ||= "#{object.inspect} is blank"
    assert object.present?, message
  end

  def assert_blank(object, message=nil)
    message ||= "#{object.inspect} is not blank"
    assert object.blank?, message
  end
end

# Methods you can use to make a mocked up Rails Request and corersponding Umlaut Request
# Pass in a URL, absolute or partial, eg "/resolve?isbn=X"
def fake_rails_request(umlaut_url)  
  # hard to figure out how to mock a request, this seems to work
  ActionController::TestRequest.new(Rack::MockRequest.env_for(umlaut_url))    
end

def fake_umlaut_request(umlaut_url)
  rails_request = fake_rails_request(umlaut_url)
  Request.find_or_create(rails_request.params, {}, rails_request)
end
