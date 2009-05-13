require File.dirname(__FILE__) + '/../test_helper'

# Example used for testing is from
# http://docs.amazonwebservices.com/AWSECommerceService/latest/DG/rest-signature.html
# Although that example itself has some bugs as of 12 may 09 doh.
# it's output isn't actually valid.
#
class AwsProductSignTest < Test::Unit::TestCase

  def setup
    @example_params = {
      "Service" => "AWSECommerceService",      
      "Operation"=>"ItemLookup",
      "ItemId"=>"0679722769",
      "ResponseGroup"=>"ItemAttributes,Offers,Images,Reviews",
      "Version" => "2009-01-06",
      "Timestamp" => "2009-05-13T10:43:28-04:00" # fixed timestamp so we can test output
    }
    @access_key = "00000000000000000000"
    @secret_key = "1234567890"

    @test_obj = AwsProductSign.new(:secret_key => @secret_key, :access_key => @access_key)
  end

  
  def test_url_encoding
    # Make sure it doesn't encode what it shouldn't.
    reserved_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~"
    assert_equal(reserved_chars, 
      @test_obj.url_encode(reserved_chars),
      "Reserved chars are not encoded")

    # Space better be %20 not plus.
    assert_equal("%20", @test_obj.url_encode(" "), "Space is encoded as %20")

    # Try a sample UTF-8 char, e acute.
    assert_equal("%C3%A9", 
      @test_obj.url_encode("\xC3\xA9"),
      "Encodes a UTF-8 char properly")
    
    # Make sure it does escape a few other sample chars, although we won't
    # try every possible char!
    chars_to_escape = "%:,/+=" # that last one is a utf-8 e acute.

    assert_equal( "%25%3A%2C%2F%2B%3D", 
     @test_obj.url_encode(chars_to_escape),
     "Some other chars are encoded properly")
  end

  def test_canonical_query_order
      ordered_keys = 
       @test_obj.canonical_querystring(@example_params).split("&").collect { |kv| kv.split("=")[0] }

      # should be sorted byte-ordered
      assert_equal(ordered_keys, 
        ["ItemId", "Operation", "ResponseGroup", "Service", "Timestamp", "Version"])            
  end

  def test_add_signature
    new_params = @test_obj.add_signature( @example_params )

    assert_not_nil( new_params["Timestamp"], "Adds timestamp" )
    assert_equal( @access_key, new_params["AWSAccessKeyId"], "Adds access key")
    assert_equal("F3xmBlY91rML36hkQTZn/N2Bk3ABIVB8NI+e/JCYpDQ=" ,     
        new_params["Signature"],
        "Adds correct signature")

    assert( @example_params != new_params, "Does not mutate input")    
  end

  def test_add_signature_mutate
    params = Hash[@example_params]

    @test_obj.add_signature!(params)

    assert_not_nil( params["Signature"], "Mutates input")
    
  end

  def test_query_string
    require 'cgi'
    params = @test_obj.add_signature(@example_params)
    query_string = @test_obj.query_with_signature(params)

    re_parsed = CGI.parse(query_string)
    # cgi puts everything in an array, flatten it please. 
    re_parsed.each {|k,v| re_parsed[k] = v.first} 

    assert_equal( params, re_parsed, "query string generated" )
    
  end
  
end
