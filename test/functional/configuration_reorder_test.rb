require 'test_helper'

# REALLY hacky attempt to test reordering of resolve_sections in Umlaut::Configuration,
# in a resolve_sections_filter method, using remove_section and insert_section configuration methods. 
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
      div_id = "document_delivery"
      original_docdel_index = @controller.umlaut_config.resolve_sections.index {|s| s[:div_id] == "document_delivery"}

      @controller.umlaut_config.configure do
        # We have to use Proc.new instead of `proc do` or `lambda do` becuase
        # of some current weirdness in Confstrut in ruby 2.1.
        # https://github.com/mbklein/confstruct/pull/21 
        add_resolve_sections_filter! Proc.new { |request, sections|
          our_section = sections.remove_section(div_id)


          our_section[:newkey] = "newvalue" 

          sections.insert_section(our_section, :before => 'fulltext')
        }
      end

      get :index, :issn => "12"

      sections = css_select(".umlaut-section")

      assert_present css_select(sections.first, ".umlaut-section.document_delivery"), "document_delivery section expected to be first"

      # But we didn't reorder the config still saved on the controller
      assert_equal original_docdel_index, @controller.umlaut_config.resolve_sections.index {|s| s[:div_id] == "document_delivery"}, "config index of document_delivery is unchanged"

      # And we didn't add a new key to it either
      our_section = @controller.umlaut_config.resolve_sections.find {|s| s[:div_id] == "document_delivery"}
      assert (!our_section.has_key?(:newkey)), "mutated original array, bad"
    end
  end
end