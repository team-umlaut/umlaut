require 'google'
require 'md5'

class GoogleSearch < Service
  def handle(request)
    query = self.build_query(request.referent)
    links = self.do_query(query)
    return request.dispatched(self, false) unless links.is_a?(Array)
    links.each do | link |
      link[:relevant] = false
      unless IrrelevantSite.is_irrelevant?(link[:url])
        if relevant = RelevantSite.is_relevant?(link[:url])
          unless relevant.is_a?(RelevantSite)
            link.merge!(relevant.get_services(link, request))          
          end
          link[:relevant] = true
        end
      end
      value_text = {:description => link[:description],
        :url => link[:url]
      }
      if link[:fulltext]
        value_text.merge!(link[:fulltext])
      end
      svc_resp = nil
      unless svc_resp = ServiceResponse.find_by_service_and_key_and_value_string(self.id, link[:title], link[:hash])
        svc_resp = ServiceResponse.create(:service=>self.id, :key=>link[:title],:value_string=>MD5.new(link[:url]),:value_text=>value_text.to_yaml)
      end	
      svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'web_link') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'web_link'])                  
      if link[:relevant]
        svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'relevant_link') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'relevant_link'])      
      end
      if link[:fulltext]
        svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'fulltext') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'fulltext'])      
        if link[:related_links] == 'true'
          svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'related') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'related'])        
        end        
      end
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
