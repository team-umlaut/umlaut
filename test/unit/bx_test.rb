# Bx Recommender Service Adaptor Test
# To inject your bX token into the testing environment, use
#     export BX_TOKEN=yourtoken
# but this isn't really necessary or useful, since this test
# will just use VCR anyway
require 'test_helper'
class BxTest < ActiveSupport::TestCase
  extend TestWithCassette
  fixtures :requests, :referents, :referent_values

  def setup
    bx_token = ENV['BX_TOKEN'] || 'BX_TOKEN'
    config = { 
      "service_id" => "Bx", 
      "priority" => "1",
      "token" => bx_token
    }
    @bx_service_adaptor = Bx.new(config)
  end

  # This test has recorded a Bx request via VCR
  # It has recommendations
  # Ignore ctx_time in the URL for VCR matching purposes
  test_with_cassette("article that has recommendations", :bx, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    # Get the relevant request fixture
    coffeemakers_request = requests(:coffeemakers)
p coffeemakers_request.referent.inspect
p coffeemakers_request.referent.referent_values.inspect
    @bx_service_adaptor.handle(coffeemakers_request)

    # Refresh with the latest from the DB after handling the service.
    coffeemakers_request.dispatched_services.reset
    coffeemakers_request.service_responses.reset

    # Get the returned 'similar' service responses
    similars = coffeemakers_request.get_service_type('similar')

    # There should be 5 'similar' service responses
    assert_equal(5, similars.length, "Ack. Similar responses have gone awry!")
  end
end
