# Test Sfx4SolrLocal searcher.
require 'test_helper'
# TODO: Abstract this out as SearchMethodTestCase
class Sfx4SearchTest < ActiveSupport::TestCase
  attr_reader :params, :context_object_from_params, :title_query_param, :search_type_param, :sfx_az_profile, :batch_size, :page
  include SearchMethods::Sfx4
  sfx4_fixtures :kb_objects, :az_title_search, :az_letter_group, :az_titles, :az_extra_info
  
  setup do
    @params = {}
    @context_object_from_params = OpenURL::ContextObject.new
    @sfx_az_profile = "default"
    @batch_size = 20
    @page = 1
  end
  
  # test "fetch urls?" do
  #   assert(SearchMethods::Sfx4.fetch_urls?)
  # end
  # 
  # test "fetch urls" do
  #   urls = SearchMethods::Sfx4.fetch_urls
  #   assert_instance_of(Array, urls)
  #   urls.each {|url| 
  #     assert_instance_of(String, url)
  #   end
  # end
  
  test "find by title contains"  do
    # Indices aren't set up in test instance
    # so commenting out this test for now.
    # @title_query_param = "Air"
    # @search_type_param = "contains"
    # (context_objects, count) = find_by_title
    # assert_equal(3, count)
    # assert_instance_of(Array, context_objects)
    # context_objects.each {|context_object| 
    #   assert_instance_of(OpenURL::ContextObject, context_object)
    #   assert_match(/Air/i, context_object.referent.get_metadata("jtitle"))
    #   assert_not_nil(context_object.referent.get_metadata("object_id"))
    # }
  end
  
  test "find by title begins with"  do
    @title_query_param = "Account"
    @search_type_param = "begins"
    (context_objects, count) = find_by_title
    assert_equal(5, count)
    assert_instance_of(Array, context_objects)
    context_objects.each {|context_object| 
      assert_instance_of(OpenURL::ContextObject, context_object)
      assert_match(/^(The )?Account/, context_object.referent.get_metadata("jtitle"))
      assert_not_nil(context_object.referent.get_metadata("object_id"))
    }
  end
  
  test "find by title exact" do
    @title_query_param = "Advances in Applied Probability"
    @search_type_param = "exact"
    (context_objects, count) = find_by_title
    assert_equal(1, count)
    assert_instance_of(Array, context_objects)
    context_objects.each {|context_object| 
      assert_instance_of(OpenURL::ContextObject, context_object)
      assert_equal("Advances in Applied Probability", context_object.referent.get_metadata("jtitle"))
      assert_not_nil(context_object.referent.get_metadata("object_id"))
    }
  end
  
  test"find by group" do
    @params[:id] = "A"
    (context_objects, count) = find_by_group
    assert_equal(16, count)
    assert_instance_of(Array, context_objects)
    context_objects.each {|context_object| 
      assert_instance_of(OpenURL::ContextObject, context_object)
      assert_match(/^(The )?A/, context_object.referent.get_metadata("jtitle"))
      assert_not_nil(context_object.referent.get_metadata("object_id"))
    }
  end
  
  test "fetch_urls?" do
    assert(SearchMethods::Sfx4.fetch_urls?)
  end
end
