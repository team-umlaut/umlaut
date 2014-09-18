require File.dirname(__FILE__) + '/../test_helper'

class ServiceTest < ActiveSupport::TestCase
  # A service that does nothing!
  class DummyService < Service
    def handle(request)
      return request.dispatched(self, true)
    end
  end

  # A preempted by service that does nothing!
  class PreemptedByDummyService < Service
    def initialize(config)
      @preempted_by = ["existing_service" => "MyDummyService"]
      super(config)
    end

    def handle(request)
      return request.dispatched(self, true)
    end
  end

  def setup
    I18n.reload! 
    @dummy_config =  {"priority" => 1, "service_id" => "MyDummyService", "type" => "DummyService"}
    @umlaut_request = fake_umlaut_request("/resolve?genre=journal&issn=0098-7484")
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
            { "service_test/dummy_service" => 
                {"class_key" => "class_key_value"},
              "my_dummy_service" =>
                {"service_id_key" => "service_id_key_value"}
            }
          }
        }
      )
      # Just make sure we set our test i18n translations right
      assert_equal "class_key_value", I18n.t("umlaut.services.service_test/dummy_service.class_key")
      assert_equal "service_id_key_value", I18n.t("umlaut.services.my_dummy_service.service_id_key")

      # Now actually test translate
      service = DummyService.new(@dummy_config)

      assert_equal "service_id_key_value", service.translate("service_id_key")
      assert_equal "class_key_value", service.translate("class_key")

      assert_equal "default_value", service.translate("missing_key", :default => "default_value")
    end
  end

  test "#display_name" do

  end
end