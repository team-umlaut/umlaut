require 'test_helper'
class ServiceStoreTest < ActiveSupport::TestCase
  test "group added to service" do
    assert_equal("default", ServiceStore.service_definition_for("SFX")["group"])
  end
end