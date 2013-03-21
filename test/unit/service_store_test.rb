require 'test_helper'
class ServiceStoreTest < ActiveSupport::TestCase
  setup :reset_service_store_classvars

  teardown do
    reset_service_store_classvars
    ServiceStore.config
    ServiceStore.service_definitions
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
  
  def reset_service_store_classvars
    # Reset ServiceStore class vars
    ["services_config_list", "service_definitions"].each do |class_var|
      class_var = "@@#{class_var}".to_sym
      ServiceStore.remove_class_variable(class_var) if ServiceStore.class_variable_defined?(class_var)
    end
  end
end