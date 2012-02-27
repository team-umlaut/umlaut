require File.dirname(__FILE__) + '/../test_helper'

class CollectionTest < ActiveSupport::TestCase
    fixtures :requests, :referents, :referent_values, :sfx_urls
     
    def setup
      # will get from ./config/services.yml. You want to test a different
      # set of services? Have to set em in ServiceStore too, as in general
      # things passed to new Collection are expected to be in ServiceStore
      @services = ServiceStore.config["default"]["services"]
      @request = requests(:simple_request)
    end
    
    def test_collection_instantiate
      collection = Collection.new(@request , @services)

      new_services = collection.instantiate_services!

      assert_not_nil new_services
      assert new_services.length > 0, "no services returned"
      new_services.each do |s|
        assert_kind_of Service, s
      end
    end

    def test_instantiate_creates_new
      collection = Collection.new(@request , @services)
      
      s1 = collection.instantiate_services!
      s2 = collection.instantiate_services!

      assert_equal 0, (s1 & s2).length, "instantiate_services! must create new services each time, not re-use objects."
      
    end

    def test_service_level
      collection = Collection.new(@request , @services)

      services = collection.instantiate_services!(:level => 'c')
      
      assert services.find {|s| s.service_id == "UlrichsCover"}, "UlrichsCover not included in instantiate_services!(:level =>'c')"
    end

    def test_requests_set
      collection = Collection.new(@request , @services)

      services = collection.instantiate_services!(:level => 'c')

      services.each do |s|
        assert_not_nil s.request, "umlaut request not set in service."
      end
    end

    def test_get_single_service
      collection = Collection.new(@request , @services)

      service = collection.instantiate_services!(:ids => ["UlrichsCover"]).first

      assert_not_nil service, "Service for UlrichsCover not returned"
      assert_not_nil service.request, "Service for UlrichsCover does not have request set."      
    end

    def test_get_nonexisting_task
      collection = Collection.new(@request , @services)

      null_services = collection.instantiate_services!(:task => :no_such_task)

      assert_equal [], null_services

      null_services = collection.instantiate_services!(:task => :no_such_task, :level => 1)

      assert_equal [], null_services
      
    end
end
