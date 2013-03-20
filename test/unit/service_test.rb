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
    @dummy_config =  {"priority" => 1, "service_id" => "DummyService"}
    @umlaut_request = requests(:simple_request)
  end

  test "preempted by wildcard other type" do
    DummyService.new(@dummy_config).handle(@umlaut_request)
    assert(PreemptedByDummyService.new(@dummy_config).preempted_by(@umlaut_request))
  end
end