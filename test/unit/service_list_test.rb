require File.dirname(__FILE__) + '/../test_helper'

class ServiceListTest < Test::Unit::TestCase

    def setup      
      # Tell the ServiceList to use our basic services.yml, not the live one.
      ServiceList.yaml_path =  RAILS_ROOT+"/lib/generators/umlaut_local/templates/services.yml-dist"      
    end
  
    # Just a good exmaple to make sure the ServiceList can give us something
    def test_definition_get
      svc_def = ServiceList.instance.definition("UlrichsLink")
      
      assert_not_nil svc_def, "Nil service def fetched for UlrichsLink"
      assert_equal "UlrichsLink", svc_def["service_id"], "Definition for  service did not have service_id set appropriately"
    end

    def test_service_instantiate
      svc = ServiceList.instance.instantiate!("UlrichsLink", nil)

      assert_not_nil svc
      assert_kind_of Service, svc
    end

    # Make sure instantiate called twice gives us two different objects
    def test_instantiate_is_new
      svc1 = ServiceList.instance.instantiate!("UlrichsLink", nil)
      svc2 = ServiceList.instance.instantiate!("UlrichsLink", nil)

      assert_not_equal(svc1, svc2, "instantiate! seems not to be returning unique new objects")
    end
  
end
