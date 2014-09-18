# Helper module for service adaptors making HTTP requests, as most do.
# Eventually this may include some HTTP request wrapper methods that
# set timeout appropriately, and perhaps even do some HTTP level cacheing.
#
# Right now, just a helper method for generating headers for proxy-like requests.

module UmlautHttp
  require 'net/http'
  require 'net/https'
  require 'uri'

  # Generate headers for a proxy-like request, so a service adaptor
  # can make a request to a foreign service that appears to be HTTP-proxied
  # from the original client browser, instead of just originating from
  # Umlaut. This in some cases helps get around service traffic limiting,
  # and in general is more honest and gives the service some good information
  # about the actual end user.
  #
  # Not generally neccesary for accessing actual APIs, but sometimes useful
  # for screen scraping, or for an API intended to be client-side JS only.
  #
  # request is an Umlaut Request, which has in it information about
  # original client request and ip. host is optional, and is the
  # ultimate destination you will be sending the proxy-like request to.
  # if supplied, a not entirely honest X-Forwarded-Host header will be
  # added. 
  def proxy_like_headers(request, host = nil)
    orig_env = request.http_env
    if (request.http_env.nil? || ! request.http_env.kind_of?(Hash))
      Rails.logger.warn("proxy_like_headers: orig_env arg is missing, proxy-like headers will be flawed. request id: #{request.id}. ")
      orig_env = {}
    end

    header = {}

    # Bunch of headers we proxy as-is from the original client request,
    # supplying reasonable defaults. 
    header["User-Agent"] = orig_env['HTTP_USER_AGENT'] || 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9) Gecko/2008061015 Firefox/3.0'
    header['Accept'] = orig_env['HTTP_ACCEPT'] || 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
    header['Accept-Language'] = orig_env['HTTP_ACCEPT_LANGUAGE'] || 'en-us,en;q=0.5'

    # Do NOT pass on accept-encoding, we don't want gzip or compressed response. 
    #header['Accept-Encoding'] = orig_env['HTTP_ACCEPT_ENCODING'] || ''
    header['Accept-Encoding'] = "identity"

    header["Accept-Charset"] = orig_env['HTTP_ACCEPT_CHARSET'] || 'UTF-8,*'

    # Set referrer to be, well, an Umlaut page, like the one we are
    # currently generating would be best. That is, the resolve link. 
    
    header["Referer"] = "http://#{orig_env['HTTP_HOST']}#{orig_env['REQUEST_URI']}"

    # Proxy X-Forwarded headers. 

    # The original Client's ip, most important and honest. Look for
    # and add on to any existing x-forwarded-for, if neccesary, as per
    # x-forwarded-for convention. 

    header['X-Forwarded-For'] =  (orig_env['HTTP_X_FORWARDED_FOR']) ?
       (orig_env['HTTP_X_FORWARDED_FOR'].to_s + ', ' + request.client_ip_addr.to_s) :
       request.client_ip_addr.to_s
       
    #Theoretically the original host requested by the client in the Host HTTP request header. We're disembling a bit.  
    header['X-Forwarded-Host'] = host if host
    # The proxy server: That is, Umlaut, us. 
    header['X-Forwarded-Server'] = orig_env['SERVER_NAME'] || '' 
    
    return header
    
  end

  # Right now the main thing this will do for you is (sort of, stupidly) 
  # maintain cookies given in redirects. 
  # Later it might do other cooler things. Returns a Net::HTTP::Response
  def http_fetch(uri, options = {})
    options[:max_redirects] ||= 8
    options[:redirects_left] ||= options[:max_redirects]
    options[:raise_on_http_error_code] = true unless options.has_key?(:raise_on_http_error_code)

      uri = URI.parse(uri) unless uri.kind_of?(URI)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == "https"
      headers = options[:headers] || {}
      headers["Cookie"] = options[:cookies] if options[:cookies]

      response = http.request_get(uri.request_uri, headers)
            
      if ( response.kind_of?(Net::HTTPRedirection))
         raise ArgumentError, "HTTP redirect too deep (max #{options[:max_redirects]})" if options[:redirects_left] <= 0

         options[:cookies] = response['Set-Cookie']
         
         options[:redirects_left] = options[:redirects_left] - 1
         
         return http_fetch(response['location'], options)
      else
        if options[:raise_on_http_error_code] 
          Rails.logger.warn("UmlautHttp#http_fetch: unexpected non-successful response: #{uri}: #{response}") unless response.is_a?(Net::HTTPSuccess)
          response.value 
        end
        return response
      end
  end
  
  
end
