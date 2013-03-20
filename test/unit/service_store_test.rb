require 'test_helper'
class ServiceStoreTest < ActiveSupport::TestCase
  setup do
    # Reset ServiceStore so all the code runs.
    ServiceStore.remove_class_variable("@@service_definitions".to_sym)
    ServiceStore.remove_class_variable("@@services_config_list".to_sym)
  end

  test "missing umlaut services yaml" do
    FileUtils.mv(File.join(Rails.root, "config", "umlaut_services.yml"), File.join(Rails.root, "config", "umlaut_services.yml.moved"))
    assert_nothing_raised{ ServiceStore.config }
    FileUtils.mv(File.join(Rails.root, "config", "umlaut_services.yml.moved"), File.join(Rails.root, "config", "umlaut_services.yml"))
  end

  test "group added to service" do
    sfx_definition = ServiceStore.service_definition_for("SFX")
    assert_equal("default", sfx_definition["group"])
    assert_equal("default", ServiceStore.instantiate_service!(sfx_definition, nil).group)
  end
end