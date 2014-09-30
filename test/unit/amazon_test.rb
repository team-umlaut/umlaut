require 'test_helper'

# Warning, amazon.rb is very poorly covered by tests, but we have
# to start somewhere.
#
# To regenerate VCR requests, you need to set in your ENV an AMAZON_API_KEY,
# AMAZON_SECRET_KEY, and AMAZON_AFFILIATE_CODE
class AmazonTest < ActiveSupport::TestCase
  extend TestWithCassette

  @@amazon_api_key        = (ENV['AMAZON_API_KEY'] || 'DUMMY_API_KEY')
  @@amazon_secret_key     = (ENV['AMAZON_SECRET_KEY'] || 'DUMMY_SECRET_KEY')
  @@amazon_associate_tag = (ENV['AMAZON_ASSOCIATE_TAG'] || "DUMMY_ASSOCIATE_TAG")

  VCR.configure do |c|
    c.filter_sensitive_data("DUMMY_API_KEY", :amazon) { @@amazon_api_key     }
    c.filter_sensitive_data("DUMMY_SECRET_KEY", :amazon) { @@amazon_secret_key }
    c.filter_sensitive_data("DUMMY_ASSOCIATE_TAG", :amazon) { @@amazon_associate_tag }
  end

  def setup
    @service_id = 'test_amazon'
    @service = Amazon.new('service_id' => @service_id, 
      'priority'      => 0,
      'api_key'       => @@amazon_api_key,
      'secret_key'    => @@amazon_secret_key,
      'associate_tag' => @@amazon_associate_tag
    )
  end


  test_with_cassette("product_advertising_api_forbidden", :amazon, 
    :match_requests_on => [:method, VCR.request_matchers.uri_without_param(:Signature, :Timestamp)]) do 
    # For some reason, Amazon won't allow some items to be looked up
    # in Product Advertising API -- this usually probably means the item
    # simply isn't listed on Amazon.  Returns:
    #<Error>
    #   <Code>AWS.ECommerceService.ItemNotAccessible</Code>
    #   <Message>This item is not accessible through the Product Advertising API.</Message>
    # </Error>
    #
    # We want the adapter to handle that smootly and just give up. 
    # This is an item that at least at time of writing was such. 

    umlaut_request = fake_umlaut_request("/resolve?rft.date=2011&rft.genre=book&rft.isbn=9780759113473&rft.place=Lanham&rft.pub=AltaMira+Press&rft.title=Stewardship%3A+Collections+and+Historic+Preservation")

    @service.handle(umlaut_request)

    ds = umlaut_request.dispatched_services.to_a.find {|ds| ds.service_id == @service_id}

    assert_present ds, "Missing DispatchedService for #{@service_id}"
    assert_equal DispatchedService::Successful, ds.status, "Expected status Succesful not #{ds.status}"
  end
end