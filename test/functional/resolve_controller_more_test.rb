# encoding: UTF-8
require 'test_helper'


# Another class for resolve controller tests, trying out other ways
# of testing, with isolated mock service definitions. 
#
# Still need to call @controller.bg_thread.wait to wait on
# all background threads before the test ends. 
class ResolveControllerMoreTest < ActionController::TestCase

  setup do
    @controller = ResolveController.new
  end

 # threads and transactional_fixtures are unhappy
 self.use_transactional_fixtures = false


  # A mess to test, indicates messy architecture, but we do what we can. 
  def test_retries_failed_temporary
    service_def = { "DummyService" => 
      { "type" => "DummyService",
        "priority" => 3,            
        "responses" => [
          { "service_type_value" => "fulltext",
            "display_text" => "created"
          }
        ]
      }
    }
    config = {"default" => {"services" => service_def}}


    with_service_config(config) do 
      @controller = ResolveController.new

      original_updated_at = Time.now - @controller.umlaut_config.requeue_failedtemporary_services_in - 1

      umlaut_request = fake_umlaut_request("/?foo=bar")
      umlaut_request.dispatched_services.create(
        :status     => DispatchedService::FailedTemporary,
        :service_id => "DummyService",
        :updated_at => original_updated_at
      )

      get(:index, {'umlaut.request_id' => umlaut_request.id})
      @controller.bg_thread.join

      ds = umlaut_request.dispatched_services(true).find {|ds| ds.service_id == "DummyService"}

      assert ds, "DispatchedService does not exist for DummyService"
      assert ds.status == DispatchedService::Successful, "DispatchedService not marked successful"
      assert ds.updated_at > original_updated_at, "DispatchedService updated_at not updated"

      assert umlaut_request.service_responses.to_a.find {|sr| sr.service_id == "DummyService" }, "ServiceResponse not created"
    end
  end

end
