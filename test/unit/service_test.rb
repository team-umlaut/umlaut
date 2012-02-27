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

    def test_write_to_session

      
      writer = DummyService.new( @dummy_config )
      writer.request = @umlaut_request
      writer.update_session( { :one => "first", :two => "second" })

      reader = DummyService.new( @dummy_config )
      reader.request = @umlaut_request
      session = reader.session()

      assert_equal "first", session[:one]
      assert_equal "second", session[:two]
      
    end
    
end
