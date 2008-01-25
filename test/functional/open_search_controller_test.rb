require File.dirname(__FILE__) + '/../test_helper'
require 'open_search_controller'

# Re-raise errors caught by the controller.
class OpenSearchController; def rescue_action(e) raise e end; end

class OpenSearchControllerTest < Test::Unit::TestCase
  def setup
    @controller = OpenSearchController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
