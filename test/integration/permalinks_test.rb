require 'test_helper'

class PermalinksTest < ActionDispatch::IntegrationTest

    
  test "missing id" do    
    get "/go/999999999"
    
    assert_response(:missing)    
  end
  
  
  
end
