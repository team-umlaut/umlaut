require File.dirname(__FILE__) + '/../test_helper'
require 'link_resolver_client_controller'

# Re-raise errors caught by the controller.
class LinkResolverClientController; def rescue_action(e) raise e end; end

class LinkResolverClientControllerTest < Test::Unit::TestCase
  def setup
    @controller = LinkResolverClientController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
