require File.dirname(__FILE__) + '/../test_helper'
require 'unapi_controller'

# Re-raise errors caught by the controller.
class UnapiController; def rescue_action(e) raise e end; end

class UnapiControllerTest < Test::Unit::TestCase
  def setup
    @controller = UnapiController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
