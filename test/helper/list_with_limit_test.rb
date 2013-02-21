require 'test_helper'
require 'nokogiri'

class ListWithLimitTest < ActionView::TestCase
  include ResolveHelper
  
  def setup
    @user_request = Request.new(:id => 999999)
  end
  
  # the visible 'ul', and the one hidden under expand-contract. 
  # second one may be empty. 
  def both_lists(str)
    dom = Nokogiri::HTML::fragment(str)
    
    first = dom.at_css("ul")
    second = dom.at_css("div.expand_contract_content ul")
    
    return [first, second, dom]
  end
    
  @@li_lambda = lambda do |item, index|
    "<li data-value='#{item}'>#{item}</li>".html_safe
  end
  
  def test_list_under_limit            
    out = list_with_limit("foo", %w{1 2 3 4}, :limit => 5, &@@li_lambda)
      
    visible_list, hidden_list = both_lists(out)
    
    assert_not_nil visible_list    
    assert_length 4, visible_list.css("li")
    
    assert_nil hidden_list    
  end
  
  def test_list_at_limit
    out = list_with_limit("foo", %w{1 2 3 4 5}, :limit => 5, &@@li_lambda)
      
    visible_list, hidden_list = both_lists(out)
    
    assert_not_nil visible_list    
    assert_length 5, visible_list.css("li")
    
    assert_nil hidden_list
  end
  
  def test_list_one_more_than_limit
    # Only FOUR orig items in visible list, then the 'more' link, then two
    # in hidden -- this makes sense for screen real estate purposes of the limit.
    out = list_with_limit("foo", %w{1 2 3 4 5 6}, :limit => 5, &@@li_lambda)
      
    visible_list, hidden_list, dom = both_lists(out)
    
    assert_not_nil visible_list    
    assert_length 4, visible_list.css("li") 
    
    assert_present dom.at_css("ul + div.expand_contract_section a.expand_contract_toggle")
        
    assert_not_nil hidden_list
    assert_length 2, hidden_list.css("li")

    assert dom.at_css(".expand_contract_toggle").text.include?("Show 2 more")
  end
  
  def test_list_many_more_than_limit    
    out = list_with_limit("foo", %w{1 2 3 4 5 6 7 8 9 10}, :limit => 5, &@@li_lambda)
      
    visible_list, hidden_list, dom = both_lists(out)
    
    assert_not_nil visible_list    
    assert_length 4, visible_list.css("li") 
    
    assert_present dom.at_css("ul + div.expand_contract_section a.expand_contract_toggle")
    
    assert_not_nil hidden_list
    assert_length 6, hidden_list.css("li") 
  end
  
  def test_html_unsafety_maintained
    out = list_with_limit("foo", %w{1 2 3 4 5 6 7 8 9 10}, :limit => 5) do |item|
      "<should be escaped> #{item}"
    end
    
    assert ! out.include?("<should be escaped>"), "Does not include un-escaped angle brackets"
    assert_equal 10, out.scan("&lt;should be escaped&gt;").length, "Includes escaped angle brackets"     
  end

end

