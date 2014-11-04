require 'vcr'

module Umlaut
  # Some methods helpful in writing automated tests against Umlaut. Used in
  # Umlaut, can also be used in your local app or Umlaut plugin. 
  #
  # Add to your test_helper.rb:
  #
  #    require 'umlaut/test_help'
  #    include Umlaut::TestHelp
  module TestHelp
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

    # Keep it in a seperate module so people can include just that if they want
    # Umlaut::TestHelp::TestWithCassette. If you've already included Umlaut::TestHelp
    # into your 
    module TestWithCassette
      # Helper to create a Test::Unit style test that is wrapped in
      # VCR.use_cassette for testing. If you supply a 'group' option, 
      # then the cassettes will be placed on the file system in a directory
      # based on that group, and the VCR cassettes will also be tagged
      # with that group name. 
      #
      # Extract this whole thing to a gem for sharing?
      #
      # An alternative to this method is using rspec (but not in Umlaut,
      # we don't use rspec) OR using minitest-rails or minitest-spec-rails
      # with minitest/spec style and the minitest-vcr gem. I've had mixed
      # success with minitest/spec in rails. 
      #
      #     include TestWithCassette
      #     test_with_cassette("do something", :group) do
      #       assert_...
      #     end
      def test_with_cassette(name, group = nil, vcr_options ={}, &block)
        # cribbed from Rails and modified for VCR
        # https://github.com/rails/rails/blob/b451de0d6de4df6bc66b274cec73b919f823d5ae/activesupport/lib/active_support/testing/declarative.rb#L25

        test_name_safe = name.gsub(/\s+/,'_')

        test_method_name = "test_#{test_name_safe}".to_sym

        raise "#{test_method_name} is already defined in #{self}" if methods.include?(test_method_name)

        cassette_name = vcr_options.delete(:cassette)
        unless cassette_name
          # calculate default cassette name from test name
          cassette_name = test_name_safe
          # put in group subdir if group
          cassette_name = "#{group}/#{cassette_name}" if group
        end

        # default tag with groupname, can be over-ridden.
        vcr_options = {:tag => group}.merge(vcr_options) if group

        if block_given?
          define_method(test_method_name) do
            VCR.use_cassette(cassette_name , vcr_options) do
              instance_eval &block
            end
          end
        else
          define_method(test_method_name) do
            flunk "No implementation provided for #{name}"
          end
        end
      end  
    end

  end
end






