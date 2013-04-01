require 'test_helper'
class SearchControllerTest < ActionController::TestCase
  setup do
    @controller = SearchController.new
  end

  test "index" do
    get :index
    assert_response :success
    assert_select "title", "Find It | Journals"
    assert_select ".citationLinker", 2
    assert_select ".list", 0
  end

  # Tests don't currently support contains searching because sdalton can't/won't
  # figure out FULLTEXT indexing in MySQL, so we'll test begins with searching.
  test "journal search" do
    return unless Sfx4::Local::AzTitle.connection_configured?
    get :journal_search, "rft.jtitle"=>"Account", "umlaut.title_search_type"=>"begins"
    assert_response :success
    assert_select "title", "Find It | Journal titles that begin with &#x27;Account&#x27;"
    assert_select ".citationLinker", 1
    assert_select ".list", 1
    assert_select ".list .citation", :minimum => 1 
    assert_select ".pagination", 2
    assert_select ".azNav", 0
  end

  test "journal list" do
    return unless Sfx4::Local::AzTitle.connection_configured?
    get :journal_list, :id => "A"
    assert_response :success
    assert_select "title", "Find It | Browse by Journal Title: A"
    assert_select ".citationLinker", 1
    assert_select ".list", 1
    assert_select ".list .citation", :minimum => 1 
    assert_select ".pagination", 2
    assert_select ".azNav", 2
  end
end
