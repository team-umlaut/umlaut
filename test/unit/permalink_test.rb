require 'test_helper'
class PermalinkTest < ActiveSupport::TestCase
  fixtures :referents, :referent_values
  test "new with values" do    
    request  = fake_umlaut_request("/resolve?format=journal&issn=0362-4331&jtitle=The+New+York+times&sid=info%3Asid%2Fsfxit.com%3Acitation")
    referent = request.referent

    permalink = nil
    assert_difference('Permalink.count') {
      permalink = Permalink.new_with_values!(referent, "info:sid/sfxit.com:citation")
    }
    assert_equal(referent.id, permalink.referent_id)
    assert_equal("info:sid/sfxit.com:citation", permalink.orig_rfr_id)
    assert_not_nil(permalink.context_obj_serialized)
    assert_equal("The New York times", permalink.restore_context_object.referent.jtitle)
  end
end