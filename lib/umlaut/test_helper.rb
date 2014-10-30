module Umlaut

  # Some methods helpful in writing automated tests against Umlaut. Used in
  # Umlaut, can also be used in your local app or Umlaut plugin. 
  #
  # Add to your test_helper.rb:
  #
  #    require 'umlaut/test_helper'
  #    include Umlaut::TestHelper
  module TestHelper
    # Methods you can use to make a mocked up Rails Request and corersponding Umlaut Request
    # Pass in a URL, absolute or partial, eg "/resolve?isbn=X"
    def fake_rails_request(umlaut_url)  
      # hard to figure out how to mock a request, this seems to work
      ActionController::TestRequest.new(Rack::MockRequest.env_for(umlaut_url))    
    end

    def fake_umlaut_request(umlaut_url)
      rails_request = fake_rails_request(umlaut_url)
      Request.find_or_create(rails_request.params, {}, rails_request)
    end

    # The list of configured services is global state. Sometimes
    # we want to test with a specific configuration list. An experimental
    # hacky way to let you do that. Yes, this is a smell of a bad design,
    # but we do what we can. 
    #
    # This is in progress and still needs more api, this is still too hard. 
    def with_service_config(hash)
      original = ServiceStore.config
      ServiceStore.config = hash
      yield
    ensure
      ServiceStore.config = original
    end

    # Assert that, for a given request, a service with a given id registered
    # a DispatchedService with status DispatchedService::Succesful
    #     assert_dispatched(umalut_request, "service_id")
    #
    # Assert that a service with a given id registered a DispatchedService
    # with another status. 
    #      assert_dispatched(umlaut_request, "service_id", DispatchedService::FailedTemporary)
    def assert_dispatched(request, service_id, status = DispatchedService::Successful)
      dispatched = request.dispatched_services.to_a.find {|ds| ds.service_id == service_id}

      assert dispatched.present?, "No DispatchedService record for service_id `#{service_id}`"

      if status
        assert_equal status, dispatched.status
      end
    end

    # Assert that for a given umlaut request, a service with a given ID
    # recorded at least one ServiceResponse of any type:
    #      assert_service_responses(umlaut_service, "service_id")
    #
    # Assert that it recorded exactly `number` of ServiceResponses
    #      assert_service_responses(umlaut_service, 'service_id', :number => 5)
    #
    # Assert that it recorded some ServiceResponses, and _at least one_ of those
    # ServiceResponses was of each of the kind(s) specified. With or without
    # :number. 
    #      assert_service_resposnes(umlaut_service, 'service_id', :includes_type => :fulltext)
    #      assert_service_resposnes(umlaut_service, 'service_id', :number => 5, :includes_type => :fulltext)
    #      assert_service_resposnes(umlaut_service, 'service_id', :number => 5, :includes_type => [:fulltext, :highlighted_link])
    #
    # On assertion success, the method will return the array of ServiceResponse 
    # objects found, OR if :number => 1, the single ServiceResponse not in an array
    # for convenience. 
    def assert_service_responses(request, service_id, options = {})
      number = options[:number]
      type_names  = Array(options[:includes_type])

      responses = request.service_responses.to_a.find_all {|r| r.service_id == service_id}

      if number
        assert_equal number, responses.length, "Found #{responses.length} ServiceResponses from service id `#{service_id}`, expected #{number}"
      else
        assert responses.length > 0, "No ServiceResponse found for service id `#{service_id}"
      end

      type_names.each do |kind|
        assert responses.find {|sr| sr.service_type_value_name == kind.to_s}, "The generated ServiceResponses for service id `#{service_id}` must include type #{kind}"
      end

      if number == 1
        return responses.first
      else
        return responses
      end

    end


  end
end