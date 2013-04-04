require File.dirname(__FILE__) + '/../test_helper'


# Umlaut::ControllerBehavior#create_collection
#
# Loads service definitions into a Collection object, based on services configuration
# and current &umlaut.service_group param. Tests. 
class CreateCollectionTest <  ActiveSupport::TestCase
	setup :reset_service_store_classvars, :set_custom_service_setup



	def set_custom_service_setup
		dummy = {"type" => "DummyService", "priority" => 3}

		# This would normally be loaded as YAML, we're going to set it
		# directly. 
		service_declerations = {
			"default" => {
				"services" => {
					"default_a" 				=> dummy.clone,
					"default_b" 				=> dummy.clone,
					"default_disabled"  => dummy.clone.merge("disabled" => true)
				}
			},			
			"group1" => {"services" =>
				"group1_a" 				=> dummy.clone,
				"group1_b" 				=> dummy.clone,
				"group1_disabled"  => dummy.clone.merge("disabled" => true)
			}},
			"group2" => {"services" =>
				"default_a" 				=> dummy.clone,
				"default_b" 				=> dummy.clone,
				"default_disabled"  => dummy.clone.merge("disabled" => true)
			}}
		}

		ServiceStore.class_variable_set("@@services_config_list", service_declerations)		
	end

  teardown do
    reset_service_store_classvars
    ServiceStore.config
    ServiceStore.service_definitions
  end

  def basic_test

  end

  def reset_service_store_classvars
    # Reset ServiceStore class vars
    ["services_config_list", "service_definitions"].each do |class_var|
      class_var = "@@#{class_var}".to_sym
      ServiceStore.remove_class_variable(class_var) if ServiceStore.class_variable_defined?(class_var)
    end
  end

end