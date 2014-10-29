require 'test_helper'
require 'tempfile'

# Only tests a few things at present
class ServiceTypeValueTest < ActiveSupport::TestCase

  def test_display_name
    I18n.locale = :en

    st = ServiceTypeValue.find("fulltext")

    assert_equal I18n.t("umlaut.service_type_names.fulltext", :count => 1), st.display_name
    assert_equal I18n.t("umlaut.service_type_names.fulltext", :count => 10), st.display_name_pluralize

  end

  def test_display_name_uses_default_when_missing
    I18n.locale = :en

    st = ServiceTypeValue.new(:id => 100000, :name => "made_up_thing")

    assert_equal I18n.t("umlaut.service_type_names.default", :count => 1), st.display_name
    assert_equal I18n.t("umlaut.service_type_names.default", :count => 10), st.display_name_pluralize
  end

  def test_can_load_custom_yaml
    file = Tempfile.new('custom_yaml')
    file.write <<-EOF
      my_custom_thing:
        display_name: Custom Thing
    EOF
    file.close

    ServiceTypeValue.merge_yml_file!(file.path)

    assert_present ServiceTypeValue.find("my_custom_thing")

    file.unlink
  end

end
