require 'test_helper'

class RequestReuseTest < ActionDispatch::IntegrationTest

    
  test "simple request" do
    sess = open_session
    
    request_params = { :issn => "012345678" }
    
    sess.get "/resolve", request_params
            
    
    # TODO: We ought to be waiting for all bg services in other
    # threads before ending test. Tricky to figure out
    # how to do cleanly, we don't even know the request id at the
    # integration level, unless we do an API request instead of
    # an HTML request. We'll just wait, sorry. 
    puts "sleeping"
    sleep 4
  end
  
  
  
end
