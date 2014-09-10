require 'test_helper'

class DispatchedServiceTest < ActiveSupport::TestCase

  def test_can_generate_service_types
    request = fake_umlaut_request("?title=foo")
    ds      = DispatchedService.new(:service_id => "Ulrichs")
    assert_equal ServiceStore.instantiate_service!("Ulrichs", request).service_types_generated, ds.can_generate_service_types
  end

  def test_can_generate_service_types_with_bum_service
    ds = DispatchedService.new(:service_id => "no_such_service")
    assert_equal [], ds.can_generate_service_types
  end

end