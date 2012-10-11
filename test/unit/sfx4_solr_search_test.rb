# Test Sfx4SolrLocal searcher.
require 'test_helper'
# TODO: Abstract this out as SearchMethodTestCase
class Sfx4SolrSearchTest < ActiveSupport::TestCase
  extend TestWithCassette
  attr_reader :params, :context_object_from_params, :title_query_param, :search_type_param, :sfx_az_profile, :batch_size, :page
  include SearchMethods::Sfx4Solr::Local
  self.use_transactional_fixtures = false
  
  setup do
    @params = {}
    @context_object_from_params = OpenURL::ContextObject.new
    @sfx_az_profile = "default"
    @batch_size = 20
    @page = 1
  end
  
  test_with_cassette("find by title contains", :sfx4_solr) do
    @title_query_param = "Air"
    @search_type_param = "contains"
    (context_objects, count) = find_by_title
    assert_equal(3, count)
    assert_instance_of(Array, context_objects)
    context_objects.each {|context_object| 
      assert_instance_of(OpenURL::ContextObject, context_object)
      assert_match(/Air/i, context_object.referent.get_metadata("jtitle"))
      assert_not_nil(context_object.referent.get_metadata("object_id"))
    }
  end
  
  test_with_cassette("find by title begins with", :sfx4_solr) do
    @title_query_param = "Account"
    @search_type_param = "begins"
    (context_objects, count) = find_by_title
    assert_equal(3, count)
    assert_instance_of(Array, context_objects)
    context_objects.each {|context_object| 
      assert_instance_of(OpenURL::ContextObject, context_object)
      assert_match(/^Account/, context_object.referent.get_metadata("jtitle"))
      assert_not_nil(context_object.referent.get_metadata("object_id"))
    }
  end
  
  test_with_cassette("find by title exact", :sfx4_solr) do
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
  
  test_with_cassette("find by group", :sfx4_solr) do
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
    assert(SearchMethods::Sfx4Solr::Local.fetch_urls?, 
      ":sfx_db is not configured in database.yml, and 'SFX controlled' URLs will not be loaded.")
  end
  
  private
  def sfx4_connection_configured?
    Sfx4::Local::AzTitle.connection_configured?
  end
end
