  require 'rubygems'
  require 'cgi'
  require 'time'
  require 'openssl'
  require 'base64'  
  
# Code to sign a request to Amazon Product Advertising API (formerly known as
# the AWS ECommerce Service), as per the specs at:
# http://docs.amazonwebservices.com/AWSECommerceService/latest/DG/index.html?RequestAuthenticationArticle.html
#
# This code based heavily on that at: http://chrisroos.co.uk/blog/2009-01-31-implementing-version-2-of-the-amazon-aws-http-request-signature-in-ruby
# Thanks Chris!
#
#  Example:
#
#  aws_signer = AwsProductSign(:access_key => "00000000000000000000", :secret_key => "1234567890")
#  params =  {
#      "Service" => "AWSECommerceService",      
#      "Operation"=>"ItemLookup",
#      "ItemId"=>"0679722769",
#      "ResponseGroup"=>"ItemAttributes,Offers,Images,Reviews"
#    }
#  query_string = aws_signer.query_with_signature(  params   )
#
#  params will have a Timestamp AWSAccessKeyId added to it, unless input
#  already had it.
#
#  Or you can get back a params hash instead of an encoded query string.
#  Beware that the Signature parameter must be URL-encoded precisely, and
#  not over-encoded: "the final signature you send in the request must be URL
#  encoded as specified in RFC 3986

#  Then you can go on to use those new params in rails url_for or the URI
#  builder of your choice. Values are not URI-escaped yet. Or mutate the
#  params passsed in with #add_signature! instead. 
#
#  Returning a new params hash, leaving your input untouched:
#
#  query_string_component = aws_signer.add_signature( params )
#
#  Or mutate your input:
#  aws_signer.add_signature!(params)
#
#
# At the moment this class can't handle a query string where you need the same
# key twice. I don't think the AWS service ever uses that though?
#
# This class also assumes a GET request. 
class AwsProductSign  
  
  def initialize(options = {})
    @secret_key = options[:secret_key]
    raise Exception.new("You must supply a :secret_key") unless @secret_key
    @access_key = options[:access_key]
  end

  def query_with_signature(hash)
    return hash_to_query( add_signature(hash)  )
  end
  
  # Pass in a hash representing params for a query string.  
  # param keys should be strings, not symbols please.
  # Will return a param with the "Signature" key/value added, without
  # modifying original. 
  def add_signature(params)
    # Make a copy to not modify original  
    add_signature!( Hash[params]  )
  end
  
  # Like #add_signature, but will mutate the hash passed in, 
  # adding a "Signature" key/value to hash passed in, and return
  # hash too.  
  def add_signature!(params)
    
    # supply timestamp and access key if not already provided
    params["Timestamp"] ||= Time.now.iso8601
    params["AWSAccessKeyId"] ||= access_key
    # Existing "Signature"? That's gotta go before we generate a new
    # signature and add it. 
    params.delete("Signature")

    query_string = canonical_querystring(params)

    string_to_sign = string_to_sign(query_string)
    
    # chomp is important!  the base64 encoded version will have a newline at the end
    # which amazon does not want. 
    digest  = OpenSSL::Digest.new('sha256')
    signature = Base64.encode64(OpenSSL::HMAC.digest(digest, secret_key, string_to_sign)).chomp
    
    params["Signature"] = signature

    #order doesn't matter for the actual request, we return the hash
    #and let client turn it into a url.
    return params
  end

  # Insist on specific method of URL encoding, RFC3986. 
  def url_encode(string)
    # It's kinda like CGI.escape, except CGI.escape is encoding a tilde when
    # it ought not to be, so we turn it back. Also space NEEDS to be %20 not +.
    return CGI.escape(string).gsub("%7E", "~").gsub("+", "%20")
  end

  # param keys should be strings, not symbols please. return a string joined
  # by & in canonical order. 
  def canonical_querystring(params)
    # I hope this built-in sort sorts by byte order, that's what's required. 
    values = params.keys.sort.collect {|key|  [url_encode(key), url_encode(params[key].to_s)].join("=") }
    
    return values.join("&")
  end

  def string_to_sign(query_string, options = {})
    options[:verb] = "GET"
    options[:request_uri] = "/onca/xml"
    options[:host] = "webservices.amazon.com"

    
    return options[:verb] + "\n" + 
        options[:host].downcase + "\n" +
        options[:request_uri] + "\n" +
        query_string
  end

  # Turns a hash into a query string, returns the query string.
  # url-encodes everything to Amazon's specifications. 
  def hash_to_query(hash)
    hash.collect do |key, value|
      
      url_encode(key) + "=" + url_encode(value)
    
    end.join("&")
  end

  def secret_key
    return @secret_key
  end
  def access_key
    return @access_key
  end
  def access_key=(a)
    @access_key = a
  end
  
end
