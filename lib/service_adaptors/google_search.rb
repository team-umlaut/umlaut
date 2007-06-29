require 'google'
require 'md5'

class GoogleSearch < Service
  def handle(request)
    query = self.build_query(request.referent)
    links = self.do_query(query)
    return request.dispatched(self, false) unless links.is_a?(Array)
    links.each do | link |
      value_text = {:description => link[:description],
        :url => link[:url]
      }
      request.add_service_response({:service=>self,:key=>link[:title],:value_string=>link[:hash],:value_text=>value_text.to_yaml},['web_link'])
    end
    return request.dispatched(self, true)    
  end
  
  def build_query(rft)
    query = ""
    metadata = rft.metadata
    ['atitle','title','jtitle','btitle','au','aulast'].each do | field |
      query << ' "'+metadata[field]+'"' if metadata[field]
    end
    return query
  end
  
  def do_query(query)
    links = []
    begin
      Timeout::timeout(5) {
        begin
          google = Google::Search.new(@api_key)
          begin      
          # send the request  
            google.search(query).resultElements.each do |result|
              # extract and collect info from the SOAP response
              links << {
                :title => result.send('title').to_s,
                :description => result.send('snippet').to_s,
                :url => result.send('url').to_s,
                :related_links => result.send('relatedInformationPresent').to_s,
                :hash => MD5.new(result.send('url').to_s)
                }
              end
    	    rescue SOAP::HTTPStreamError
    	      return nil
    	    end    
    	  rescue  WSDL::XMLSchema::Parser::UnknownElementError
    	    return nil
    	  end 
      }
    rescue Timeout::Error
      return nil
    end
    return links
  end    
end
