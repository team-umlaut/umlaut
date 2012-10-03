require 'test_helper'
class ResolveControllerTest < ActionController::TestCase
  extend TestWithCassette
  # attr_accessor :driver
  fixtures :requests, :referents, :referent_values, :dispatched_services, :service_responses
  
  setup do
    # @driver = Selenium::WebDriver.for :firefox
    @controller = ResolveController.new
  end
  
  test_with_cassette("nytimes by issn", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    get :index, "umlaut.request_id" => 80
    assert_response :success
    assert_select "title", "Find It | The New York times"
    assert_select "h1", "Find It"
    assert_select "h2", "Find Resource"
    assert_select ".umlaut-main .umlaut-resource-info dl" do |dls|
      assert_equal 1, dls.size
      dls.each do |dl|
        assert_select dl, "dt", 2
        assert_select dl, "dt" do |dts|
          assert dts.first, "Title:"
          assert dts.last, "ISSN:"
        end
        assert_select dl, "dd", 2
        assert_select dl, "dd" do |dds|
          assert dds.first, "The New York times"
          assert dds.last, "0362-4331"
        end
      end
    end
    assert_select ".umlaut-main .umlaut-section.fulltext" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".response_list", 1
        assert_select section, ".response_list" do |response_lists|
          assert_select section, "li.response_item", 4
        end
      end
    end
    assert_select ".umlaut-sidebar .umlaut-section.export_citation" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".response_list", 1
      end
    end
    assert_select ".umlaut-sidebar .umlaut-section.highlighted_link" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".response_list", 1
      end
    end
  end
end