class Ezproxy < Service
  required_config_params :proxy_server, :proxy_password, :proxy_url_path
  
  require 'rexml/document'
  require 'uri'
  require 'net/http'
  require 'cgi'  
  
  def handle(request)
    
  end

  def link_out_filter(url)
    return proxy_urls( [url] )[0]
  end
  
  def proxy_urls(urls)
    url_doc = REXML::Document.new
    doc_root = url_doc.add_element "proxy_url_request", {"password"=>@proxy_password}
    urls_elem = doc_root.add_element "urls"
    urls.each { | link |
      url_elem = urls_elem.add_element "url"
      url_elem.text = link
    }
    proxy_links = []  
    begin
      resp = Net::HTTP.post_form URI.parse(@proxy_server+@proxy_url_path), {"xml"=>url_doc.to_s}    
      proxy_doc = REXML::Document.new resp.body
    rescue Timeout::Error
      RAILS_DEFAULT_LOGGER.error "Timed out connecting to EZProxy"
      return proxy_links
    end

  
    REXML::XPath.each(proxy_doc, "/proxy_url_response/proxy_urls/url") { | u |
      if u.attributes["proxy"] == "true"
        p_url = u.attributes["scheme"]+"://"+u.attributes["hostname"]+":"+u.attributes["port"]+u.attributes["login_path"]
        if u.attributes["encode"] == "true"
          p_url += CGI::escape(u.get_text.value)
        else
          p_url += u.get_text.value
        end
        proxy_links << [u.get_text.value, p_url]
      end
    }    
    return proxy_links
  end
  
  def proxy_links(links)
    if links.empty?
      return
    end
    urls = []
    links.each { | ln |
      urls << ln[:url]
    }
    proxied_urls = self.proxy_url(urls)
    proxied_links = []
    proxied_urls.each { | u, prx |
      if urls.index(u)
        links[urls.index(u)][:url] = prx      
        proxied_links << links[urls.index(u)]
      end
    }
    return proxied_links
  end

end