require 'test_helper'

class JournalTocsServiceTest < ActiveSupport::TestCase
  extend TestWithCassette
  
  # TODO: Fix up umlaut to make it easier to create request/referent
  # objects for testing!  
  def journal_request_with_metadata(hash = {})
    context_object = OpenURL::ContextObject.new
    context_object.referent.set_format('journal')
    
    hash.each_pair do |key, value|    
      context_object.referent.set_metadata(key.to_s, value.to_s)
    end
    
    rft = Referent.create_by_context_object(context_object)
    
    req = Request.new
    req.referent = rft
    req.save!
    
    return req
  end
  
  def setup
    @service = JournalTocs.new({"priority" => 3, "service_id" => "JournalTocs"})
  end
  
  
  test_with_cassette("found issn", :journal_tocs_service) do
    req     = journal_request_with_metadata("issn" => "1532-2890")    
    retVal  = @service.handle(req)
    
    assert_present req.service_responses, "Added a service response"
    
    assert_equal 1, req.service_responses.length
  end
  
  test_with_cassette("not found issn", :journal_tocs_service) do
    req     = journal_request_with_metadata("issn" => "badissn")
    retVal  = @service.handle(req)
    
    assert_blank req.service_responses, "No service responses added"
  end
  
  
  
end

