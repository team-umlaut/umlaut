require 'test_helper'


# The ExportEmailController provides custom interactions
# for the ExportEmail service. 
class ExportEmailControllerTest < ActionController::TestCase
  fixtures :requests, :referents, :referent_values, :dispatched_services, :service_responses

  setup do
    @email_service_response = service_responses(:service_response3)
    @txt_holding_service_response = service_responses(:service_response9)
  end

  test "layout" do
    get(:email, :id => @email_service_response.id)
    assert_response :success
    assert_select "body div.umlaut.container", 1
    assert_select "div.email", 1
  end

  test "layout xhr" do
    xhr :get, :email, :id => @email_service_response.id
    assert_response :success
    # Assert that no layout was included in the request
    assert_select "body", 0
    assert_select "div.umlaut.container", 0
    assert_select "div.email", 1
  end

  test "send email" do
    to_addr = "nobody@example.org"
    post :send_email, :id => @email_service_response.id, :email => to_addr


    # Mail was sent
    assert !ActionMailer::Base.deliveries.empty?
    assert ActionMailer::Base.deliveries.find do |message|
      message.to.include? to_addr      
    end

    assert_select "div", :text => /Sent to #{to_addr}/
  end
end