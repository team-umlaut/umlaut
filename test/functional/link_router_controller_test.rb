require 'test_helper'
class LinkRouterControllerTest < ActionController::TestCase
  fixtures :service_responses
  test "index" do
    service_response = service_responses(:service_response8)
    get :index, {id: service_response.id}
    assert_response :redirect
    assert_redirected_to "http://holding.library.edu/DOCID"
  end

  test "error" do
    assert_raises(ActiveRecord::RecordNotFound) {
      get :index, {id: "this should throw an error"}
    }
  end
end