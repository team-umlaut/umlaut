# tests for SFX service
# Only the the simplest of tests are done so far. To do more advanced tests,
# request fixtures for more cases should be created.
require 'test_helper'
class SfxTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  def setup    
    @sfx_default = ServiceStore.instantiate_service!("SFX", nil)
  end

  def test_initialize_minimum
    sfx = Sfx.new({"priority"=>1, "base_url" => "http://sfx.library.example.edu/local"})
    assert_equal(1, sfx.priority)    
  end
  
  # Use VCR to provide a deterministic SFX search.
  # Ignore ctx_time in the URL for VCR matching purposes
  # TODO: Check more of the response
  test_with_cassette("nytimes by issn", :sfx, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    #nytimes_request = requests(:nytimes)

    nytimes_request = fake_umlaut_request("/resolve?format=journal&genre=journal&jtitle=The+New+York+times&issn=0362-4331")

    # Clear request
    nytimes_request.service_responses.each do |service_response|
      service_response.destroy
    end
    nytimes_request.dispatched_services.reload
    nytimes_request.service_responses.reload
    assert_equal 0, nytimes_request.service_responses.count
    response = @sfx_default.do_request(@sfx_default.initialize_client(nytimes_request))
    @sfx_default.parse_response(response, nytimes_request)
    nytimes_request.dispatched_services.reload
    nytimes_request.service_responses.reload
    assert_equal 10, nytimes_request.service_responses.size
    first_service_response = nytimes_request.service_responses.first
    assert_not_nil(first_service_response.view_data[:proxy], "Proxy is nil")
    assert(first_service_response.view_data[:proxy], "Proxy is false")
  end
end