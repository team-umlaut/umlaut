#  By default, proxies a URL after checking the EZProxy API to see if
#  it's proxy-able. But you can set the config param precheck_with_api
#  to false, and then this will simply automatically proxy all links
#  from umlaut responses.  That is useful if you have your EZProxy
#  server set to automatically redirect non-proxyable URLs to the original
#  non-proxied version, the API check may not be neccesary. 

# Required parameters:
#   proxy_server: hostname of EZProxy instance (no "http://", just hostname)
#
#   optional params:
#   proxy_password (the ProxyURLPassword  parameter in ezproxy.cfg; must be set
#                   to turn on proxy url api feature ).
#   proxy_url_path: defaults to /proxy_url, the default ezproxy path to call api
#   exclude_hosts: array of hosts to exclude from proxying _even if_ found in
#                  ezproxy config. Each entry can be a string, in which
#                  case it must match host portion of url exactly. Or it can 
#                  be a regexp, which will be tested against entire url.
#                  (supply a string inside // markers. eg '/regexp/' ).
#
#   This service is a link_out_filter service, it must be setup in your
#   services.yml with "task: link_out_filter ".


class Ezproxy < Service
  required_config_params :proxy_server
  
  require 'rexml/document'
  require 'uri'
  require 'net/http'
  require 'cgi'  

  def initialize(config)
    @precheck_with_api = true

    @proxy_login_path = "/login"
    
    super(config)
    
    
    @proxy_url_path ||= "/proxy_url"
    @proxy_url_path = "/" + @proxy_url_path unless @proxy_url_path[0,1] = '/'

    @exclude ||= []
  end

  # This is meant to be called as task:link_out_filter, it doesn't have an
  # implementation for handle, it implements link_out_filter() instead. 
  def handle(request)
     raise "Not implemented."
  end

  # Hook method called by Umlaut. 
  # Returns a proxied url if it should be proxied, or nil if the url
  # can not or does not need to be proxied. 
  def link_out_filter(orig_url, service_type, other_args = {})
    # remove trailing or leading whitespace from url, it makes it
    # an illegal URL anyway, but maybe we can rescue it? Marc 856's
    # sometimes have accidental trailing whitespace. 
    orig_url = orig_url.strip
    
    # bad uri? Forget it.    
    return nil unless valid_url?( orig_url )
    
    # If it's already proxied, leave it alone.
    return nil if already_proxied(orig_url)

    return nil if excluded?(orig_url)

    new_url = nil
    if @precheck_with_api
      new_url =  check_proxy_urls( [orig_url] ).values[0]
    else
      new_url =  auto_proxy_url(orig_url)
    end
    
    return new_url
  end

  def valid_url?(url)
    begin
      raise Exception.new("Empty url!") if url.blank?
      URI.parse( url )
      return true
    rescue Exception => e
      Rails.logger.error("Bad uri sent to ezproxy service. Can not parse. url: <#{url}>")
      return false
    end
  end

  # see @exclude config parameter. 
  def excluded?(url)    
    return false if @exclude.blank?
    
    @exclude.each do |entry|
      if ((entry[0,1] == '/') && (entry[entry.length()-1 ,1 ] == '/'))
        # regexp. Match against entire url. 
        re = Regexp.new( entry )
        return true if re =~ url
      elsif (entry.kind_of? Regexp)
        return true if entry =~ url
      else
        # ordinary string. Just match against host.
        host = URI.parse(url).host
        return true if host == entry
      end      
    end
    # looped through them all, no match?
    return false
  end

  # pass in a url, this just mindlessly sends it through your
  # ezproxy instance. 
  def auto_proxy_url(url)
    return "http://" + @proxy_server + @proxy_login_path + "?qurl=" + CGI.escape(url)
  end
  
  # Pass in an array of URLs. Will determine if they are proxyable by EZProxy.
  # Returns a hash, where the key is the original URL, and the value is the
  # proxied url---or nil if could not be proxied. 
  def check_proxy_urls(urls)
    url_doc = REXML::Document.new
    doc_root = url_doc.add_element "proxy_url_request", {"password"=>@proxy_password}
    urls_elem = doc_root.add_element "urls"
    urls.each { | link |
      url_elem = urls_elem.add_element "url"
      url_elem.text = link
    }
    begin
      resp = Net::HTTP.post_form(URI.parse('http://' + @proxy_server+@proxy_url_path), {"xml"=>url_doc.to_s})    
      proxy_doc = REXML::Document.new resp.body
    rescue Timeout::Error
      Rails.logger.error "Timed out connecting to EZProxy"
      return proxy_links
    rescue Exception => e
      Rails.logger.error "EZProxy error, NOT proxying URL + #{e}"
    end
  
    return_hash = {}
    REXML::XPath.each(proxy_doc, "/proxy_url_response/proxy_urls/url") { | u |
      unless (u && u.get_text) # if u is empty... weird, but skip it.
        Rails.logger.error "EZProxy response seems to be missing some pieces.\n   Urls requested: #{urls.join(',')}\n   EZProxy api request xml: #{url_doc.to_s}\n   EZProxy response: #{proxy_doc.to_s}"
      end
      orig_url = u.get_text.value
      return_hash[orig_url] = nil
    
      if u.attributes["proxy"] == "true"
        proxied_url = u.attributes["scheme"]+"://"+u.attributes["hostname"]+":"+u.attributes["port"]+u.attributes["login_path"]
        if u.attributes["encode"] == "true"
          proxied_url += CGI::escape(u.get_text.value)
        else
          proxied_url += u.get_text.value
        end

        return_hash[orig_url] = proxied_url
                
      end
    }    
    return return_hash
  end

  # pass in url as a string. Return true if the
  # url is already pointing to the proxy server
  # configured. 
  def already_proxied(url)
    uri_obj = URI.parse(url)

    return uri_obj.host == @proxy_server && uri_obj.path == @proxy_login_path
  end

end
