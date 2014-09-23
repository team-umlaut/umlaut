require 'test_helper'

class CollectionTest < ActiveSupport::TestCase
    self.use_transactional_fixtures = false
    extend TestWithCassette




    fixtures :requests, :referents, :referent_values, :sfx_urls
     
    def setup
      # will get from ./config/services.yml. You want to test a different
      # set of services? Have to set em in ServiceStore too, as in general
      # things passed to new Collection are expected to be in ServiceStore
      @services = ServiceStore.config["default"]["services"]
      @request = requests(:simple)
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

    # Allowing new episodes because some of our outgoing requests in current
    # demo config are to non-existing hostnames, which VCR can't properly record. 
    test_with_cassette("live dispatch", :collection, :record => :new_episodes, :match_requests_on => [:method, :uri_without_ctx_tim]) do        
      request = fake_umlaut_request('/resolve?sid=google&auinit=S&aulast=Madsbad&atitle=Mechanisms+of+changes+in+glucose+metabolism+and+bodyweight+after+bariatric+surgery&id=doi:10.1016/S2213-8587(13)70218-3&title=The+Lancet+Diabetes+%26+Endocrinology&volume=2&issue=2&date=2014&spage=152&issn=2213-8587')

      collection = Collection.new(request , @services)
      # We don't care about exceptions for now
      collection.forward_background_exceptions = false

      bg_thread = collection.dispatch_services!

      # some are still in background
      bg_thread.join

      # Check to make sure all services were recorded as
      # dispatched, and with a completion status. We don't care
      # if they were succesful or not, we're not testing the actual
      # services, and some may have failed lacking api keys etc. We just
      # care they are registered as finished. 

      @services.each do |service|
        dispatch = request.dispatched_services.to_a.find {|ds| ds.service_id = service[0]}

        assert_present dispatch, "Dispatch not recorded for #{service[0]}"

        assert dispatch.completed?, "Dispatch status '#{dispatch.status}' is not a finished status for #{service[0]}"
      end
    end


    # A mess to test, indicates messy architecture, but we do what we can. 
    def test_retries_failed_temporary
      service_def = { "DummyService" => 
        { "type" => "DummyService",
          "priority" => 3,            
          "responses" => [
            { "service_type_value" => "fulltext",
              "display_text" => "created"
            }
          ]
        }
      }
      config = {"default" => {"services" => service_def}}


      with_service_config(config) do 
        retry_after = 10
        original_updated_at = Time.now - retry_after - 1

        request = fake_umlaut_request("/?foo=bar")
        request.dispatched_services.create(
          :status     => DispatchedService::FailedTemporary,
          :service_id => "DummyService",
          :updated_at => original_updated_at
        )

        collection = Collection.new(request, 
          ServiceStore.global_service_store.determine_services,
          Confstruct::Configuration.new(:requeue_failedtemporary_services => retry_after))
        collection.dispatch_services!.join

        ds = request.dispatched_services(true).find {|ds| ds.service_id == "DummyService"}

        assert ds, "DispatchedService does not exist for DummyService"
        assert ds.status == DispatchedService::Successful, "DispatchedService not marked successful"
        assert ds.updated_at > original_updated_at, "DispatchedService updated_at not updated"

        assert request.service_responses.to_a.find {|sr| sr.service_id == "DummyService" }, "ServiceResponse not created"
      end
    end

end
