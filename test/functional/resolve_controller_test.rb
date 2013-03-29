# encoding: UTF-8
require 'test_helper'
class ResolveControllerTest < ActionController::TestCase
  extend TestWithCassette
  fixtures :requests, :referents, :referent_values, :dispatched_services, :service_responses
  
  setup do
    @controller = ResolveController.new
  end
  
  test_with_cassette("nytimes by issn", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    get :index, "umlaut.request_id" => 80
    assert_response :success
    assert_select "title", "Find It | The New York times"
    assert_select "h1", "Find It"
    assert_select "h1", "Find Resource"
    assert_select ".umlaut_resolve .main_column .resource_info table table#citation" do |citation_tables|
      assert_equal 1, citation_tables.size
      citation_tables.each do |citation_table|
        assert_select citation_table, "tr", 2
        assert_select citation_table, "tr" do |trs|
          assert_select trs.first, "td.largeTextb", :count => 1, :text => "Title:"
          assert_select trs.first, "td.largeText", :count => 1, :text => "The New York times"
          assert_select trs.last, "td div.smallTextb", :count => 1, :text => "ISSN:"
          assert_select trs.last, "td span.smallText", :count => 1, :text => "0362-4331"
        end
      end
    end
    assert_select ".umlaut_resolve .main_column .umlaut_section.fulltext" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".response_list", 1
        assert_select section, ".response_list" do |response_lists|
          assert_select section, "li.response_item", 4
        end
      end
    end
    assert_select ".umlaut_resolve .main_column .umlaut_section.holding" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, "table", 1
      end
    end
    assert_select ".umlaut_resolve .sidebar .umlaut_section.export_citation" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".response_list", 1
      end
    end
    assert_select ".umlaut_resolve .sidebar .umlaut_section.highlighted_link" do |sections|
      assert_equal 1, sections.size
      sections.each do |section|
        assert_select section, ".response_list", 1
      end
    end
  end

  test_with_cassette("fulltext with edition warning", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = requests(:momo)
    get(:index, {'umlaut.request_id' => umlaut_request.id})
    assert_response :success
    assert_select 'div#fulltext ul.response_list li.response_item' do |elements|
      assert_equal(1, elements.size)
      elements.each do |element|
        assert_select element, "a", {:count => 1, :href => "", :text => "the Internet Archive: Open Source Book"}
        assert_select element, 'div.edition_warning', {:count => 1,
          :text => "Edition information Momo, ovvero l&#x27;arcana storia dei ladri di tempo e della bambina che restituÃ¬ agli uomini il tempo trafugato"}
      end
    end
  end

  test_with_cassette("no holdings", :resolve, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    umlaut_request = requests(:advocate)
    get(:index, {'umlaut.request_id' => umlaut_request.id, "umlaut.institution" => "NYU"})
    assert_response :success
    assert_select 'div#fulltext ul.response_list li.response_item' do |elements|
      assert_equal(1, elements.size)
      elements.each do |element|
        assert_select element, "a", {:count => 1, :href => "", :text => "Gale Cengage Newsstand"}
        assert_select element, 'div.response_coverage_statement', {:count => 1, :text => "Available from 2009."}
      end
    end
    # Assert no holdings
    assert_select 'div#holding div.umlaut-holdings', :count => 0
  end
end