require 'test_helper'


# ServiceStore.determine_services
# 
# Loads service definitions into a Collection object, based on services configuration
# and current &umlaut.service_group param. Tests.
class DetermineServicesTest <  ActiveSupport::TestCase
  setup :set_custom_service_store

  def set_custom_service_store
    dummy = {"type" => "DummyService", "priority" => 3}

    # This would normally be loaded as YAML, we're going to set it
    # directly.
    service_declerations = {
      "default" => {
        "services" => {
          "default_a"         => dummy.clone,
          "default_b"         => dummy.clone,
          "default_disabled"  => dummy.clone.merge("disabled" => true)
        }
      },

      "group1" => {
        "services" => {
          "group1_a"        => dummy.clone,
          "group1_b"        => dummy.clone,
          "group1_disabled"  => dummy.clone.merge("disabled" => true)
        }
      },

      "group2" => {
        "services" => {
          "group2_a"        => dummy.clone,
          "group2_b"        => dummy.clone,
          "group2_disabled"  => dummy.clone.merge("disabled" => true)
        }
      }
    }

    @service_store = ServiceStore.new
    @service_store.config = service_declerations
  end

  def test_basic
    service_list = @service_store.determine_services

    # default group services
    assert_include service_list.keys, "default_a"
    assert_include service_list.keys, "default_b"

    # but not the disabled one
    assert_not_include service_list.keys, "default_disabled"

    # No group1 or group2
    assert_nil service_list.keys.find {|key| key.start_with? "group1"}
    assert_nil service_list.keys.find {|key| key.start_with? "group2"}
  end

  def test_add_groups
    service_list = @service_store.determine_services %w[group2 group1]

    ["default_a", "default_b", "group1_a", "group1_b", "group2_a", "group2_b"].each do |service_id|
      assert_include service_list.keys, service_id
    end

    ["default_disabled", "group1_disabled", "group2_disabled"].each do |service_id|
      assert_not_include service_list.keys, service_id
    end
  end

  def test_add_group_no_default
    service_list = @service_store.determine_services %w{group1 -default}

    # does not include default ones
    assert_nil service_list.keys.find {|id| id.start_with? "default_"}

    # does include group1 ones
    assert_include service_list.keys, "group1_a"
    assert_include service_list.keys, "group1_b"
  end

  # Should this raise a clear error instead? For now, we ignore.
  def test_missing_service_group_ignored
    # Not raise
    service_list = @service_store.determine_services %w{non_existing_group}
  end

  def test_multi_default_groups
    store = multi_default_group_store

    service_list = store.determine_services

    assert_include service_list.keys, "default_a"
    assert_include service_list.keys, "other_default_a"
  end

  def test_multi_default_disable
    store = multi_default_group_store

    service_list = store.determine_services %w{-other_default}

    assert_include service_list.keys, "default_a"
    assert_not_include service_list.keys, "other_default_a"
  end


  # A terrible way and place to test this, but our legacy code is tricky, currently
  # consider this better than nothing. =
  #
  # the Request.co_params_fingerprint must take account of new "umlaut.service_group", to make sure
  # a cached request same but for different umlaut.service_group is NOT re-used
  def test_params_fingerprint_includes_service_group

    req_string = "/?issn=12345678&"
    req     = ActionDispatch::TestRequest.new Rack::MockRequest.env_for(req_string)
    req_sg1 = ActionDispatch::TestRequest.new Rack::MockRequest.env_for(req_string + "&umlaut.service_group[]=group1")
    req_sg2 = ActionDispatch::TestRequest.new Rack::MockRequest.env_for(req_string + "&umlaut.service_group[]=groupother")

    fingerprint     = Request.co_params_fingerprint(  Request.context_object_params req  )
    fingerprint_sg1 = Request.co_params_fingerprint(  Request.context_object_params req_sg1  )
    fingerprint_sg2 = Request.co_params_fingerprint(  Request.context_object_params req_sg2  )

    assert_not_equal fingerprint, fingerprint_sg1
    assert_not_equal fingerprint, fingerprint_sg2
    assert_not_equal fingerprint_sg1, fingerprint_sg2
  end


  def multi_default_group_store
    dummy = {"type" => "DummyService", "priority" => 3}

    service_declerations = {
      "default" => {
        "services" => {
          "default_a"         => dummy.clone,
          "default_b"         => dummy.clone,
          "default_disabled"  => dummy.clone.merge("disabled" => true)
        }
      },

      "other_default" => {
        "default"  => true,
        "services" => {
          "other_default_a"        => dummy.clone
        }
      },

      "extra_group" => {
        "services" => {
          "extra_group_a"        => dummy.clone,
        }
      }
    }

    store = ServiceStore.new
    store.config = service_declerations

    return store
  end

end
