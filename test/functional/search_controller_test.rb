require 'test_helper'
class SearchControllerTest < ActionController::TestCase
  setup do
    @controller = SearchController.new
  end

  test "index" do
    get :index
    assert_response :success
    assert_select "title", "Find It | Journals"
    assert_select ".umlaut-search-form", 2
    assert_select ".umlaut-results", 0
  end

  # Tests don't currently support contains searching because sdalton can't/won't
  # figure out FULLTEXT indexing in MySQL, so we'll test begins with searching.
  test "journal search" do
    return unless Sfx4::Local::AzTitle.connection_configured?
    get :journal_search, "rft.jtitle"=>"Account", "umlaut.title_search_type"=>"begins"
    assert_response :success
    assert_select "title", "Find It | Journal titles that begin with &#x27;Account&#x27;"
    assert_select ".umlaut-search-form", 1
    assert_select ".umlaut-results", 1
    assert_select ".umlaut-results .umlaut-result", :minimum => 1
    assert_select ".umlaut-pagination", 2
    assert_select ".umlaut-az", 0
  end

  test "journal list" do
    return unless Sfx4::Local::AzTitle.connection_configured?
    get :journal_list, :id => "A"
    assert_response :success
    assert_select "title", "Find It | Browse by Journal Title: A"
    assert_select ".umlaut-search-form", 1
    assert_select ".umlaut-results", 1
    assert_select ".umlaut-results .umlaut-result", :minimum => 1 
    assert_select ".umlaut-pagination", 2
    assert_select ".umlaut-az", 1
  end

  test "journal list pagination" do
    return unless Sfx4::Local::AzTitle.connection_configured?
    # Awkward stubbing, since creating enough test data is a pain
    # Store the original az batch size class variable in a local variable
    original_az_batch_size = SearchController.class_variable_get(:@@az_batch_size)
    # Then override it with the stub, we reset it down below.
    SearchController.class_variable_set(:@@az_batch_size, 5)
    get :journal_list, :id => "A"
    assert_response :success
    assert_select ".umlaut-pagination" do |paginations|
      paginations.each do |pagination|
        assert_select pagination, "ul > li > a:not(.next)" do |anchors|
          anchors.each_with_index do |anchor, index|
            assert_equal("/journal_list/A/#{index+2}", anchor.attributes["href"])
          end
        end
      end
    end
    # Reset the az batch size class variable
    SearchController.class_variable_set(:@@az_batch_size, original_az_batch_size)
  end
end
