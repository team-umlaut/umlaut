module Umlaut

  # Some methods helpful in writing automated tests against Umlaut. Used in
  # Umlaut, can also be used in your local app or Umlaut plugin. 
  #
  # Add to your test_helper.rb:
  #
  #    require 'umlaut/test_helper'
  #    include Umlaut::TestHelper
  module TestHelper
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

    # The list of configured services is global state. Sometimes
    # we want to test with a specific configuration list. An experimental
    # hacky way to let you do that. Yes, this is a smell of a bad design,
    # but we do what we can. 
    #
    # This is in progress and still needs more api, this is still too hard. 
    def with_service_config(hash)
      original = ServiceStore.config
      ServiceStore.config = hash
      yield
    ensure
      ServiceStore.config = original
    end
  end
end