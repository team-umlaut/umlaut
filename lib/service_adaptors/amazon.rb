require 'hpricot'
class Amazon < Service
  attr_reader :url
  def handle(request)
    return request.dispatched(self, true) if request.referent.metadata["isbn"].nil? or request.referent.metadata["isbn"].blank?
    # get the Amazon query
    query = "Service=AWSECommerceService&SubscriptionId=#{@api_key}&Operation=ItemLookup&ResponseGroup=Large,Subjects&ItemId="+request.referent.metadata["isbn"].gsub(/[^0-9X]/,'')           
    uri = URI.parse(self.url+'?'+query)
    links = []
    # send the request
    http = Net::HTTP.new(uri.host, 80)  
    http.open_timeout = 5
    http.read_timeout = 5
    begin
      http_response = http.send_request('POST', uri.path + '?' + uri.query)    
    rescue TimeoutError
      # Try again later if we timeout
      return request.dispatched(self, false)
    end
    self.parse_response(request, http_response)
    return request.dispatched(self, true)
  end
  
  def parse_response(request, http_response)
    aws = Hpricot(http_response.body)
    # extract and collect info from the xml    

    # if we get an error from Amazon, just return
    return request.dispatched(self, true) if err = (aws/"/ItemLookupResponse/Items/Request/Errors/Error")
    asin = (aws/"/ItemLookupResponse/Items/Item/ASIN").inner_html
    # collect cover art urls
    ["small","medium","large"].each do | size |
      if img = (aws/"/ItemLookupResponse/Items/Item/"+size.capitalize+"Image/URL")
        request.add_service_response({:service=>self, :key=>size, :value_string=>asin},['image'])            
      end
    end               
    
    # get description
    if desc = (aws/"/ItemLookupResponse/Items/Item/EditorialReviews/EditorialReview/Content")
      request.add_service_response({:service=>self, :key=>'description', :value_string=>asin, :value_text=>desc.inner_html},['description'])
    end
    
    # we want to highlight Amazon to link to 'search in this book', etc.
    item_url = (aws/"ItemLookupResponse/Items/Item/DetailPageURL")
    request.add_service_response({:service=>self,:key=>'url',:value_string=>asin, :value_text=>item_url.inner_html},['highlighted_link'])

    # gather Amazon's subject headings
    (aws/"/ItemLookupResponse/Items/Item/Subjects/Subject").each do |subject|
      request.add_service_response({:service=>self, :key=>'Amazon',:value_string=>asin,:value_alt_string=>subject.inner_html},['subject'])
    end
    
    # Get Amazon's 'similar products' to help recommend other useful items
    (aws/"/ItemLookupResponse/Items/Item/SimilarProducts/SimilarProduct").each do |similar|
      request.add_service_response({:service=>self,:key=>'book', :value_string=>(similar/"/ASIN").inner_html, :value_alt_string=>(similar/"/Title").inner_html},['similar_item'])
    end
    request.referent.enhance_referent('format', 'book', false) unless request.referent.format == 'book'
    unless request.referent.metadata['btitle']
      if title = (aws/"/ItemLookupResponse/Items/Item/ItemAttributes/Title")
        request.referent.enhance_referent('btitle', title.inner_html)
      end
    end
    unless request.referent.metadata['au']
      if author = (aws/"/ItemLookupResponse/Items/Item/ItemAttributes/Author")
        request.referent.enhance_referent('au', author.inner_html)
      end
    end    
    unless request.referent.metadata['pub']
      if pub = (aws/"/ItemLookupResponse/Items/Item/ItemAttributes/Publisher")
        request.referent.enhance_referent('pub', pub.inner_html)
      end
    end      
    unless request.referent.metadata['tpages']
      if tpages = (aws/"/ItemLookupResponse/Items/Item/ItemAttributes/NumberOfPages")
        request.referent.enhance_referent('tpages', tpages.inner_html)
      end
    end     
  end
end
