# tests for internet archive service
# Only the the simplest of tests are done so far. To do more advanced tests,
# request fixtures for more cases should be created.
require 'test_helper'
class InternetArchiveTest < ActiveSupport::TestCase  
  extend TestWithCassette

  def setup    
    @ia_default = ServiceStore.instantiate_service!("InternetArchive", nil)
  end

  test_with_cassette("momo by title author", :internet_archive) do    
    request = fake_umlaut_request("/resolve?isbn=038519093X&aufirst=Michael&aulast=Ende&btitle=Momo&genre=book&isbn=038519093X&pub=Doubleday")
    
    # Clear out the current responses.
    request.service_responses.each do |service_response|
      service_response.destroy
    end
    @ia_default.handle(request)
    request.referent.referent_values.reset
    request.dispatched_services.reset
    request.service_responses.reset
    fulltexts = request.get_service_type('fulltext')
    assert((not fulltexts.empty?), "IA didn't return any fulltext")
    assert_equal(1, fulltexts.length, "IA returned an unexpected number of fulltexts")
    fulltext = fulltexts.first
    assert_equal("http://archive.org/details/MomoOvveroLarcanaStoriaDeiLadriDiTempoEDellaBambinaCheRestitu", 
      fulltext.url, "IA Service constructed an unexpected URL")
    view_data = fulltext.view_data
    assert((not view_data.nil?), "IA full text view data is nil")

    assert_equal("the Internet Archive: Open Source Books", view_data[:display_text], "IA display text is unexpected")
  end
end