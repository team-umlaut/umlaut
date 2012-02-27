require File.dirname(__FILE__) + '/../test_helper'

class ServiceTest < ActiveSupport::TestCase
  fixtures :requests
  
      # A service that does nothing!
      class DummyService < Service
        def handle(request)
          return request.dispatched(self, true)
        end
      end      
  
    def setup
      @dummy_config =  {"priority" => 1}
      @umlaut_request = requests(:simple_request)
    end

    
end
