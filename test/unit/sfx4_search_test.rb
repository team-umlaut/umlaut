# Test Sfx4SolrLocal searcher.
require 'test_helper'
# TODO: Abstract this out as SearchMethodTestCase
class Sfx4SearchTest < ActiveSupport::TestCase
  attr_reader :params, :context_object_from_params, :title_query_param, :search_type_param, :sfx_az_profile, :batch_size, :page
  include SearchMethods::Sfx4
  self.use_transactional_fixtures = false
  sfx4_fixtures :kb_objects, :az_title_search, :az_letter_group, :az_titles, :az_extra_info
  
  setup do
    @params = {}
    @context_object_from_params = OpenURL::ContextObject.new
    @sfx_az_profile = "default"
    @batch_size = 20
    @page = 1
  end
  
  test "find by title contains"  do
    # Indices aren't set up in test instance
    # so commenting out this test for now.
    # @title_query_param = "Air"
    # @search_type_param = "contains"
    # # (context_objects, count) = find_by_title
    # # Only run the assertions if we are using our mock instance
    # # otherwise just check that this doesn't raise errors since
    # # it's non-deterministic.
    # if(self.class.sfx4_mock_instance?)
    #   assert_equal(3, count)
    #   assert_instance_of(Array, context_objects)
    #   context_objects.each {|context_object| 
    #     assert_instance_of(OpenURL::ContextObject, context_object)
    #     assert_match(/Air/i, context_object.referent.get_metadata("jtitle"))
    #     assert_not_nil(context_object.referent.get_metadata("object_id"))
    #   }
    # end
  end
  
  test "find by title begins with"  do
    return unless sfx4_connection_configured?
    @title_query_param = "Account"
    @search_type_param = "begins"
    (context_objects, count) = find_by_title
    # Only run the assertions if we are using our mock instance
    # otherwise just check that this doesn't raise errors since
    # it's non-deterministic.
    if(self.class.sfx4_mock_instance?)
      assert_equal(5, count)
      assert_instance_of(Array, context_objects)
      context_objects.each {|context_object| 
        assert_instance_of(OpenURL::ContextObject, context_object)
        assert_match(/^(The )?Account/, context_object.referent.get_metadata("jtitle"))
        assert_not_nil(context_object.referent.get_metadata("object_id"))
      }
    end
  end
  
  test "find by title exact" do
    return unless sfx4_connection_configured?
    @title_query_param = "Advances in Applied Probability"
    @search_type_param = "exact"
    (context_objects, count) = find_by_title
    # Only run the assertions if we are using our mock instance
    # otherwise just check that this doesn't raise errors since
    # it's non-deterministic.
    if(self.class.sfx4_mock_instance?)
      assert_equal(1, count)
      assert_instance_of(Array, context_objects)
      context_objects.each {|context_object| 
        assert_instance_of(OpenURL::ContextObject, context_object)
        assert_equal("Advances in Applied Probability", context_object.referent.get_metadata("jtitle"))
        assert_not_nil(context_object.referent.get_metadata("object_id"))
      }
    end
  end
  
  test"find by group" do
    return unless sfx4_connection_configured?
    @params[:id] = "A"
    (context_objects, count) = find_by_group
    # Only run the assertions if we are using our mock instance
    # otherwise just check that this doesn't raise errors since
    # it's non-deterministic.
    if(self.class.sfx4_mock_instance?)
      assert_equal(16, count)
      assert_instance_of(Array, context_objects)
      context_objects.each {|context_object| 
        assert_instance_of(OpenURL::ContextObject, context_object)
        assert_match(/^(The )?A/, context_object.referent.get_metadata("jtitle"))
        assert_not_nil(context_object.referent.get_metadata("object_id"))
      }
    end
  end
  
  test "fetch_urls?" do
    assert(SearchMethods::Sfx4.fetch_urls?, 
      ":sfx_db is not configured in database.yml, and 'SFX controlled' URLs will not be loaded.")
  end
  
  private
  def sfx4_connection_configured?
    Sfx4::Local::AzTitle.connection_configured?
  end
end
