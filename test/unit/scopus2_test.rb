require 'test_helper'
require 'uri'

class Scopus2Test < ActiveSupport::TestCase
  extend TestWithCassette

  # Set shell env SCOPUS_KEY to your api key to test fresh http
  # connections, if you can't use the ones cached by VCR. 

  # Filter API key out of VCR cache for tag :scopus, which we'll use
  # in this test. 
  @@api_key = (ENV["SCOPUS_KEY"] || "DUMMY_API_KEY")
  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_API_KEY", :scopus) { @@api_key }
  end

  def setup
    @service       = Scopus2.new('service_id' => 'test_scopus2', 'api_key' => @@api_key, 'priority' => 0)
  end

  def make_rails_request(umlaut_url)  
    # hard to figure out how to mock a request, this seems to work
    ActionController::TestRequest.new(Rack::MockRequest.env_for(umlaut_url))    
  end

  def make_umlaut_request(umlaut_url)
    rails_request = make_rails_request(umlaut_url)
    Request.find_or_create(rails_request.params, {}, rails_request)
  end

  
  # Actual openurl sent by google scholar, including a doi. 
  # Do we correctly create a scopus doi query?  
  def test_doi_query  
    doi = '10.1007/s10350-006-0578-2'
    umlaut_request = make_umlaut_request("/resolve?sid=google&auinit=J&aulast=Rafferty&atitle=Practice+parameters+for+sigmoid+diverticulitis&id=doi:#{CGI.escape doi}&title=Diseases+of+the+colon+%26+rectum&volume=49&issue=7&date=2006&spage=939&issn=0012-3706")
    
    scopus_query = @service.scopus_query(umlaut_request)

    assert_equal %Q{DOI("#{doi}")}, scopus_query
  end

  # No doi, but full citation. scopus query?
  def test_non_doi_query
    umlaut_request = make_umlaut_request("/resolve?sid=google&auinit=J&aulast=Rafferty&atitle=Practice+parameters+for+sigmoid+diverticulitis&title=Diseases+of+the+colon+%26+rectum&volume=49&issue=7&date=2006&spage=939&issn=0012-3706")

    scopus_query = @service.scopus_query(umlaut_request)

    expected_query = "VOLUME(\"49\") AND ISSUE(\"7\") AND PAGEFIRST(\"939\")  AND (ISSN(\"00123706\") OR EISSN(\"00123706\"))"
    assert_equal expected_query, scopus_query
  end

  # journal title but no issn
  def test_no_issn_query
    umlaut_request = make_umlaut_request("/resolve?sid=google&auinit=J&aulast=Rafferty&atitle=Practice+parameters+for+sigmoid+diverticulitis&title=Diseases+of+the+colon+%26+rectum&volume=49&issue=7&date=2006&spage=939&jtitle=Diseases+of+the+colon+%26+rectum")

    scopus_query = @service.scopus_query(umlaut_request)

    expected_query = "VOLUME(\"49\") AND ISSUE(\"7\") AND PAGEFIRST(\"939\")  AND EXACTSRCTITLE(\"Diseases of the colon & rectum\")"
    assert_equal expected_query, scopus_query
  end

  # Not enough to make a query, no journal title or issn
  def test_insufficient_metadata_query
    umlaut_request = make_umlaut_request("/resolve?sid=google&auinit=J&aulast=Rafferty&atitle=Practice+parameters+for+sigmoid+diverticulitis&title=Diseases+of+the+colon+%26+rectum&volume=49&issue=7&date=2006&spage=939")

    scopus_query = @service.scopus_query(umlaut_request)

    assert_nil scopus_query    
  end

  def test_pmid_query
    umlaut_request = make_umlaut_request("/resolve?sid=google&pmid=123456&atitle=ignore&aulast=ignore&issn=12345678")

    scopus_query = @service.scopus_query(umlaut_request)

    assert_equal "PMID(\"123456\")", scopus_query
  end

  def test_isbn_query
    umlaut_request = make_umlaut_request("/resolve?sid=google&isbn=1234567890&title=ignore&aulast=ignore")

    scopus_query = @service.scopus_query(umlaut_request)

    assert_equal "ISBN(\"1234567890\")", scopus_query
  end

  # Live test, with VCR recording
  test_with_cassette("live test with result", :scopus) do    
    umlaut_request = make_umlaut_request("/resolve?sid=google&auinit=J&aulast=Rafferty&atitle=Practice+parameters+for+sigmoid+diverticulitis&title=Diseases+of+the+colon+%26+rectum&volume=49&issue=7&date=2006&spage=939&issn=0012-3706")
      
    @service.handle_wrapper(umlaut_request)

    cited_by_responses = umlaut_request.service_responses.find_all {|r| r.service_type_value_name == "cited_by"}
    assert_length 1, cited_by_responses
    
    cited_by_response = cited_by_responses.first
    assert_match URI::regexp, cited_by_response.url, "cited_by has valid url"
    assert_present cited_by_response.display_text

    similar_responses = umlaut_request.service_responses.find_all {|r| r.service_type_value_name == "similar"}
    assert_length 2, similar_responses

    similar_responses.each do |similar_response|
      assert_match URI::regexp, similar_response.url, "similar-type response has valid url"
      assert_present similar_response.display_text, "similar-type response has display_text"
    end

    dispatch = umlaut_request.dispatched_services.find {|ds| ds.service_id == @service.service_id}
    assert_present dispatch
    assert_equal DispatchedService::Successful, dispatch.status
  end

  test_with_cassette("live test with no hits", :scopus) do
    umlaut_request = make_umlaut_request("/resolve?sid=google&atitle=adfadfadf&title=adfadf&volume=4900&issue=700&date=1900&spage=93900&issn=0012-3706")

    @service.handle_wrapper(umlaut_request)

    assert_length 0, umlaut_request.service_responses

    dispatch = umlaut_request.dispatched_services.find {|ds| ds.service_id == @service.service_id}
    assert_present dispatch
    assert_equal DispatchedService::Successful, dispatch.status
  end

  test_with_cassette("live trigger scopus error", :scopus) do
    # Make a new service object that we mock to send a back request to Scopus, so
    # we can verify our error handling
    service = Scopus2.new('service_id' => 'test_scopus2', 'api_key' => @@api_key, 'priority' => 0)
    service.extend( Module.new do 
      def scopus_query(request)
        # malformed query meant to trigger an error from scopus
        "DOI("
      end
    end)

    umlaut_request = make_umlaut_request("/resolve?sid=google&atitle=adfadfadf&title=adfadf&volume=4900&issue=700&date=1900&spage=93900&issn=0012-3706")
    service.handle_wrapper(umlaut_request)

    assert_empty umlaut_request.service_responses

    dispatch = umlaut_request.dispatched_services.find {|ds| ds.service_id == service.service_id}
    assert_present dispatch
    assert_equal DispatchedService::FailedFatal, dispatch.status
  end

end
