# Test for S
require 'test_helper'
# TODO: Abstract this out as SearchMethodTestCase
class Sfx4SolrTest < ActiveSupport::TestCase
  attr_reader :params, :context_object_from_params, :title_query_param, :search_type_param
  include SearchMethods::Sfx4Solr::Local
  self.use_transactional_fixtures = false
  sfx4_fixtures :kb_objects, :az_title_search, :az_letter_group, :az_titles # , :az_extra_info
  
  setup do
    @params = {}
    @context_object_from_params = OpenURL::ContextObject.new
  end
  
  test "sfx4solr local searcher find by title contains" do
    @title_query_param = "Air"
    @search_type_param = "contains"
    VCR.use_cassette('sfx4_solr/find_by_title_contains') do
      (context_objects, count) = find_by_title
      assert_equal(3, count)
      assert_instance_of(Array, context_objects)
      context_objects.each {|context_object| 
        assert_instance_of(OpenURL::ContextObject, context_object)
        assert_match(/Air/i, context_object.referent.get_metadata("jtitle"))
        assert_not_nil(context_object.referent.get_metadata("object_id"))
      }
    end
  end
  
  test "sfx4solr local searcher find by title begins with" do
    @title_query_param = "Account"
    @search_type_param = "begins"
    VCR.use_cassette('sfx4_solr/find_by_title_begins_with') do
      (context_objects, count) = find_by_title
      assert_equal(3, count)
      assert_instance_of(Array, context_objects)
      context_objects.each {|context_object| 
        assert_instance_of(OpenURL::ContextObject, context_object)
        assert_match(/^Account/, context_object.referent.get_metadata("jtitle"))
        assert_not_nil(context_object.referent.get_metadata("object_id"))
      }
    end
  end
  
  test "sfx4solr local searcher find by title exact" do
    @title_query_param = "Advances in Applied Probability"
    @search_type_param = "exact"
    VCR.use_cassette('sfx4_solr/find_by_title_exact') do
      (context_objects, count) = find_by_title
      assert_equal(1, count)
      assert_instance_of(Array, context_objects)
      context_objects.each {|context_object| 
        assert_instance_of(OpenURL::ContextObject, context_object)
        assert_equal("Advances in Applied Probability", context_object.referent.get_metadata("jtitle"))
        assert_not_nil(context_object.referent.get_metadata("object_id"))
      }
    end
  end
  
  test "sfx4solr local searcher find by group" do
    @params[:id] = "A"
    VCR.use_cassette('sfx4_solr/find_by_group') do
      (context_objects, count) = find_by_group
      assert_equal(16, count)
      assert_instance_of(Array, context_objects)
      context_objects.each {|context_object| 
        assert_instance_of(OpenURL::ContextObject, context_object)
        assert_match(/^(The )?A/, context_object.referent.get_metadata("jtitle"))
        assert_not_nil(context_object.referent.get_metadata("object_id"))
      }
    end
  end
end
