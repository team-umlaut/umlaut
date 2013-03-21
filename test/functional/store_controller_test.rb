require 'test_helper'
class StoreControllerTest < ActionController::TestCase
  fixtures :permalinks, :requests, :referents, :referent_values
  test "index with permalink referent" do
    permalink = permalinks(:nytimes)
    referent = permalink.referent
    get :index, {id: permalink.id}
    # assert_redirected_to doesn't work as advertised so HACK!
    assert(@controller.location.starts_with?("http://test.host/resolve?umlaut.referent_id=#{referent.id}&url_ver=Z39.88-2004&url_ctx_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Actx&ctx_ver=Z39.88-2004&"), "Not redirecting to the correct location.")
    assert(/rft\.issn=0362-4331/===@controller.location, "In the redirect url, rft.issn is expected to be \"0362-4331\", but isn't. Actual location: #{@controller.location}")
    assert(/rft\.jtitle=The\+New\+York\+times/===@controller.location, "In the redirect url, rft.jtitle is expected to be \"The New York times\", but isn't. Actual location: #{@controller.location}")
  end

  test "index without permalink referent" do
    permalink = permalinks(:expired_referent)
    get :index, {id: permalink.id}
    assert_response :redirect
    # assert_redirected_to doesn't work as advertised so HACK!
    assert(@controller.location.starts_with?("http://test.host/resolve?umlaut.referent_id="), "Not redirecting to the correct location.")
    assert(/rft\.issn=0028792X/===@controller.location, "In the redirect url, rft.issn is expected to be \"0028792X\", but isn't. Actual location: #{@controller.location}")
    assert(/rft\.jtitle=The\+New\+Yorker/===@controller.location, "In the redirect url, rft.jtitle is expected to be \"The New Yorker\", but isn't. Actual location: #{@controller.location}")
  end

  test "error" do
    get :index, {id: "this should not be found"}
    assert_response :not_found
    assert_select 'title', "The page you were looking for doesn't exist (404)"
  end
end