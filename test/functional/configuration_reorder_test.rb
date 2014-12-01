require 'test_helper'

# Somewhat hacky tests of our Umlaut::Configuration setting in UmlautController
# and subclasses
class ConfigurationReorderTest < ActionController::TestCase
  # threads and transactional_fixtures are unhappy
  self.use_transactional_fixtures = false

  setup do
    @umlaut_services = 
      {"default" => 
        {"services" => 
          { "DummyService" => 
            { "type" => "DummyService",
              "priority" => 3,            
              "responses" => [
                { "service_type_value" => "fulltext",
                  "display_text" => "created"
                },
                { "service_type_value" => "document_delivery",
                  "display_text" => "created"
                }
              ]
            }
          }
        }
      }

    @controller = ResolveController.new

    # hacky way to have custom configuration just for this test class, just
    # for the controller we just instantiated. 
    @controller.umlaut_config = Confstruct::Configuration.new
    UmlautConfigurable.set_default_configuration!(@controller.umlaut_config)
  end


  test "can reorder" do
    with_service_config(@umlaut_services) do
      # We're going to try to make document_delivery first, in a filter
      div_id = "document_delivery"
      original_docdel_index = @controller.umlaut_config.resolve_sections.index {|s| s[:div_id] == "document_delivery"}

      @controller.umlaut_config.configure do
        resolve_sections_filter(lambda do |request, sections|
          last_section = sections.remove_section(div_id)
          sections.insert_section(last_section, :before => 'fulltext')
        end) 
      end    

      get :index, :issn => "12"

      sections = css_select(".umlaut-section")

      assert_present css_select(sections.first, ".umlaut-section.document_delivery"), "document_delivery section expected to be first"

      # But we didn't reorder the config still saved on the controller
      assert_equal original_docdel_index, @controller.umlaut_config.resolve_sections.index {|s| s[:div_id] == "document_delivery"}, "config index of document_delivery is unchanged"
    end
  end
end