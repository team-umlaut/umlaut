require 'test_helper'

# Some basic tests for referent.to_citation, which returns a hash of various citation
# information. 
class RequestTest < ActiveSupport::TestCase

  test "add_service_response" do
    request = fake_umlaut_request("/resolve?title=foo&author=bar")
    service = DummyService.new("priority" => 3, "service_id" => "DummyService")

    request.add_service_response(
      :service=>service, 
      :url=>"http://example.com",
      :display_text=>"something",      
      :service_type_value => :highlighted_link
    )

    assert_length 1, request.service_responses

    response = request.service_responses.first

    assert_equal service.service_id, response.service_id

    assert_equal request.id,           response.request.id
    assert_equal ServiceTypeValue[:highlighted_link], response.service_type_value

    assert_equal "http://example.com", response.view_data[:url]
    assert_equal "something",          response.view_data[:display_text]

  end

end