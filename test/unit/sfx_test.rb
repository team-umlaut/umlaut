# tests for google book search service
# Only the the simplest of tests are done so far. To do more advanced tests,
# request fixtures for more cases should be created.
require 'test_helper'
class SfxTest < ActiveSupport::TestCase  
  extend TestWithCassette
  fixtures :requests, :referents, :dispatched_services, :service_responses
  
  def setup    
    @sfx_default = ServiceStore.instantiate_service!("SFX", nil)
  end

  def test_initialize_minimum
    sfx = Sfx.new({"priority"=>1, "base_url" => "http://sfx.library.example.edu/local"})
    assert_equal(1, sfx.priority)    
  end
  
  # Use VCR to provide a deterministic SFX search.
  # TODO: Check more of the response
  test_with_cassette("nytimes by issn", :sfx, :match_requests_on => [:method, :uri_without_ctx_tim]) do
    nytimes_resquest = requests(:nytimes)
    response = @sfx_default.do_request(@sfx_default.initialize_client(nytimes_resquest))
    # puts response.inspect
  end
end