require File.dirname(__FILE__) + '/../test_helper'

class ServiceResponseTest < ActiveSupport::TestCase

  def test_view_data
    sr = ServiceResponse.new
    sr.take_key_values(
      :service_id => "DummyService",
      :display_text => "Display text",
      :notes => "notes",
      :my_own_key => "my_own_key",
      :service_type_value => :fulltext
    )

    assert_equal "Display text", sr.view_data[:display_text]
    assert_equal "Display text", sr.view_data['display_text']

    assert_equal "notes", sr.view_data[:notes]
    assert_equal "notes", sr.view_data["notes"]

    assert_equal "my_own_key", sr.view_data[:my_own_key]
    assert_equal "my_own_key", sr.view_data['my_own_key']

    assert sr.view_data[:service_type_value].present?
    assert_equal "fulltext", sr.view_data[:service_type_value]
  end

  def test_truncates_really_long_display_text
    sr = ServiceResponse.new
    sr.take_key_values(
      :service_id => "DummyService",
      :display_text => ("really really long and " * 300),
      :service_type_value => :fulltext
    )
    sr.save!
  end

  # A service that does nothing!
  class DummyService < Service
    def handle(request)
      return request.dispatched(self, true)
    end

    # Optional method for display-time transformations
    # of view_datahash
    def transform_view_data(hash)
      hash[:added_by_transform_view_data] = "added by transform"
      return hash
    end
  end

  def test_view_data_i18n
    I18n.backend.store_translations("en", 
        {"umlaut" => 
          {"services" => 
            { "service_response_test/dummy_service" => 
                {"localized_text" => "localized text value"},
            }
          }
        }
      )

    I18n.with_locale("en") do
      sr = ServiceResponse.new
      sr.instance_variable_set("@service", DummyService.new({'service_id' => "dummy", 'priority' => '3'}))      
      sr.take_key_values(:display_text => "raw text", :display_text_i18n => "localized_text", :notes_i18n => "localized_text")

      assert_equal "localized text value", sr.view_data[:display_text]
      assert_equal "localized text value", sr.view_data[:notes]
    end
  end

  def test_transform_view_data
    sr = ServiceResponse.new
    sr.instance_variable_set("@service", DummyService.new({'service_id' => "dummy", 'priority' => '3'}))      
    assert_equal "added by transform", sr.view_data[:added_by_transform_view_data]      
  end

end
