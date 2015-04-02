require 'test_helper'

# Some basic tests for referent.to_citation, which returns a hash of various citation
# information. 
class RequestTest < ActiveSupport::TestCase

  test "add_service_response" do
    request = fake_umlaut_request("/resolve?title=foo&author=bar")
    request.service_responses.to_a
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

  test "get_service_type_with_bum_response" do
    request = fake_umlaut_request("/resolve?title=foo&author=bar")
    request.add_service_response(
      :service => Service.new('service_id' => "NO_SUCH", "priority" => 3),      
      :service_type_value => :highlighted_link
    )
    request.add_service_response(
      :service => ServiceStore.instantiate_service!('DummyService', request),
      :service_type_value => :highlighted_link
    )

    assert_length 1, request.get_service_type(:highlighted_link)
  end

  test "DC format metadata does not raise" do
    # Can't promise we can do much useful with it, but it shouldn't raise
    params = Rack::Utils.parse_nested_query 'rfr_id=info%3Asid%2Fzotero.org%3A2&rft.source=The+New+Yorker&rft.type=webpage&rft.description=How+Xi+Jinping+took+control+of+China.&rft.identifier=http%3A%2F%2Fwww.newyorker.com%2Fmagazine%2F2015%2F04%2F06%2Fborn-red&ctx_ver=Z39.88-2004&url_ver=Z39.88-2004&rft.title=Rise+of+the+Red+Prince&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Adc&umlaut.force_new_request=true'
    co = OpenURL::ContextObject.new_from_form_vars( params )
    rft = Referent.create_by_context_object(co)
  end



end