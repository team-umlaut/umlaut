class YahooSearch < Service
  require 'md5'
  require 'json/lexer'
  attr_reader :url, :api_key
  def handle(request)
    raise "YahooSearch: Url or API key are nil. They must be filled out in config for YahooSearch service. The password should be an API key from Yahoo: https://developer.yahoo.com/wsregapp/index.php" if self.url.nil? or self.api_key.nil?
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
      value_text.merge!(link[:fulltext]) if link[:fulltext]
        
      svc_resp = nil
      unless svc_resp = ServiceResponse.find_by_service_and_key_and_value_string(self.id, link[:title], link[:hash])
        svc_resp = ServiceResponse.create(:service=>self.id,:key=>link[:title],:value_string=>MD5.new(link[:url]),:value_text=>value_text.to_yaml)
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
    ['atitle','title','jtitle','btitle','au','aulast', 'date'].each do | field |
      query << ' "'+metadata[field]+'"' if metadata[field]
    end
	if query == ""
		return false
	end   
    return "appid=#{@api_key}&query="+CGI::escape(query)+"&results=50&start=1&output=json"    
  end
  
  def do_query(query)
    links = []
    yws = '/WebSearchService/V1/webSearch'
    yahoo_uri = URI.parse(self.url+yws)

    # send the request
    http = Net::HTTP.new(yahoo_uri.host, 80)  
    http_response = http.send_request('POST', yahoo_uri.path + '?' + query)
    begin
      json = JSON::Lexer.new(http_response.body).nextvalue
      return if json.nil? or json["ResultSet"]["totalResultsReturned"] == 0

      json["ResultSet"]["Result"].each do |result|
        links << {
            :title => result['Title'],
            :description => result['Summary'],
            :url => result['Url'],
            :hash => MD5.new(result['Url'])}
      end
    rescue RuntimeError
      return nil
    end    
    return links
  end    


end
