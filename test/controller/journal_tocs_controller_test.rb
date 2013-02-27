require 'test_helper'

class JournalTocsControllerTest < ActionController::TestCase
  extend TestWithCassette
  
  test_with_cassette("no issn", :journal_tocs_controller) do
    get :show
    assert_response :error
  end
  
  test_with_cassette("bad issn", :journal_tocs_controller) do
    get :show, {:issn => "bad_issn"}
    assert_response :missing
  end
  
  test_with_cassette("good issn", :journal_tocs_controller) do
    get :show, {:issn => "1600-5740"}
    
    assert_response :success
    assert_not_nil assigns(:results)
    
    assert_template "bento_search/_std_item"
    
    assert_select "div.bento_item", :mininum => 5
  end
  
  test_with_cassette("good issn atom", :journal_tocs_controller) do
    get :show, {:issn => "1600-5740", :format => "atom"}
    
    assert_response :success

    assert_not_nil assigns(:results)    
    
    assert_template "bento_search/atom_results", :locals => {:atom_results => @results}
    assert_template "bento_search/_atom_item"
  end
  
end
