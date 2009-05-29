require File.dirname(__FILE__) + '/../test_helper'

class CollectionTest < Test::Unit::TestCase
    fixtures :requests, :referents, :referent_values
  
    def setup      
      # Tell the ServiceList to use our basic services.yml, not the live one.
      ServiceList.yaml_path =  RAILS_ROOT+"/lib/generators/umlaut_local/templates/services.yml-dist"
      InstitutionList.yaml_path = RAILS_ROOT+"/lib/generators/umlaut_local/templates/institutions.yml-dist"

      # Make something that looks like a session hash type thing, so we
      # can init a collection with it. 
      @fake_session = Hash.new
      class << @fake_session
         def session_id ; "000001" ; end
      end
    end

     
    def test_collection_instantiate
      collection = Collection.new(requests(:simple_request) , @fake_session)

      new_services = collection.instantiate_services!
      assert_not_nil new_services
      assert new_services.length > 0
      new_services.each do |s|
        assert_kind_of Service, s
      end
    end

    def test_instantiate_creates_new
      collection = Collection.new(requests(:simple_request) , @fake_session)
      
      s1 = collection.instantiate_services!
      s2 = collection.instantiate_services!

      assert_equal 0, (s1 & s2).length, "instantiate_services! must create new services each time, not re-use objects."
      
    end

    def test_service_level
      collection = Collection.new(requests(:simple_request) , @fake_session)

      services = collection.instantiate_services!(:level => 'c')
      
      assert services.find {|s| s.service_id == "UlrichsCover"}, "UlrichsCover not included in instantiate_services!(:level =>'c')"
    end

    def test_requests_set
      collection = Collection.new(requests(:simple_request) , @fake_session)

      services = collection.instantiate_services!(:level => 'c')

      services.each do |s|
        assert_not_nil s.request, "umlaut request not set in service."
      end
    end

    def test_get_single_service
      collection = Collection.new(requests(:simple_request) , @fake_session)

      service = collection.instantiate_service!("UlrichsCover")

      assert_not_nil service, "Service for UlrichsCover not returned"
      assert_not_nil service.request, "Service for UlrichsCover does not have request set."
      
    end
end
