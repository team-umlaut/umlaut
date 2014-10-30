require 'test_helper'
class ServiceStoreTest < ActiveSupport::TestCase
  setup :reset_service_store
  teardown :reset_service_store, :force_lazy_load_service_store
  

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

  test "manually set services" do
    # force original from disk  to load
    ServiceStore.config 
    ServiceStore.service_definitions

    # But then set our own instead
    ServiceStore.config = {
      "default" => {
        "services" => {
          "dummy" => {"type" => "DummyService", "priority" => 3}
        }
      }
    }

    assert_length 1, ServiceStore.service_definitions
    assert_present ServiceStore.service_definition_for("dummy")
  end

  test "ERB in umlaut_services.yml" do
    dummy_service_config = ServiceStore.service_definition_for("DummyService")
    assert_equal "this value comes from ERB: test", dummy_service_config["value_from_erb"]
  end

  
  def reset_service_store
    ServiceStore.reset!    
  end
  def force_lazy_load_service_store
    ServiceStore.config
    ServiceStore.service_definitions
  end


end