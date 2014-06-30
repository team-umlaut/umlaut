require File.dirname(__FILE__) + '/../test_helper'

class ServiceTest < ActiveSupport::TestCase
  fixtures :requests

  # A service that does nothing!
  class DummyService < Service
    def handle(request)
      return request.dispatched(self, true)
    end
  end

  # A preempted by service that does nothing!
  class PreemptedByDummyService < Service
    def initialize(config)
      @preempted_by = ["existing_service" => "DummyService"]
      super(config)
    end

    def handle(request)
      return request.dispatched(self, true)
    end
  end

  def setup
    I18n.reload! 
    @dummy_config =  {"priority" => 1, "service_id" => "DummyService", "type" => "DummyServiceClass"}
    @umlaut_request = requests(:simple)
  end

  test "preempted by wildcard other type" do
    DummyService.new(@dummy_config).handle(@umlaut_request)
    assert(PreemptedByDummyService.new(@dummy_config).preempted_by(@umlaut_request))
  end

  test "Service#translate" do
    I18n.with_locale(:en) do
      I18n.backend.store_translations("en", 
        {"umlaut" => 
          {"services" => 
            {"type" =>
              {"service_test/dummy_service" => 
                {"class_key" => "class_key_value"}
              },
            "dummy_service" =>
              {"service_id_key" => "service_id_key_value"}
            }
          }
        }
      )
      # Just make sure we set our test i18n translations right
      assert_equal "class_key_value", I18n.t("umlaut.services.type.service_test/dummy_service.class_key")
      assert_equal "service_id_key_value", I18n.t("umlaut.services.dummy_service.service_id_key")

      # Now actually test translate
      service = DummyService.new(@dummy_config)

      assert_equal "service_id_key_value", service.translate("service_id_key")
      assert_equal "class_key_value", service.translate("class_key")

      assert_equal "default_value", service.translate("missing_key", "default_value")
    end
  end

  test "#display_name" do

  end
end