require 'test_helper'

class RequestReuseTest < ActionDispatch::IntegrationTest
  
    
  test "reuse_of_request_in_session" do
    sess = open_session
    
    request_params = { :issn => "012345678" }
    
    sess.get "/resolve", request_params 
            
    created_request_id = sess.assigns[:user_request].id
    
    get "/resolve", request_params
    
    # re-use same user_request object    
    assert_equal( created_request_id, sess.assigns[:user_request].id  )
    
  end
  
  test "no re-use from different session" do
    request_params = { :issn => "012345678" }
    
    sess1 = open_session                    
    sess1.get "/resolve", request_params        
    created_request_id = sess1.assigns[:user_request].id
  
    sess2 = open_session      
    sess2.get "/resolve", request_params        
    # no re-use, different umlaut Reqeust object.     
    assert_not_equal( created_request_id, sess2.assigns[:user_request].id  )    
  end
  
end
