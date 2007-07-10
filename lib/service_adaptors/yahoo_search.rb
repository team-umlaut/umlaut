class YahooSearch < Service
  require 'md5'
  require 'json/lexer'
  
  required_config_params :url, :api_key
  attr_reader :url, :api_key
  
  def handle(request)
    raise "YahooSearch: Url or API key are nil. They must be filled out in config for YahooSearch service. The API key should be an API key from Yahoo: https://developer.yahoo.com/wsregapp/index.php" if self.url.nil? or self.api_key.nil?

    catch (:no_op) do
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
    # If we made it here, we have a no-op. Okay, we didn't do anything,
    # but we chose not to, that's success. 
    return request.dispatched(self, true)
  end
  
  def build_query(rft)
    query = ""
    metadata = rft.metadata
    ['atitle','title','jtitle','btitle','au','aulast', 'date'].each do | field |
      query << ' "'+metadata[field]+'"' if metadata[field]
    end
	if query == ""
    # We can't and shouldn't perform the service, just give up.  
    throw :no_op
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
      return if json.nil?
      
      return [] if json["ResultSet"]["totalResultsReturned"] == 0

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
