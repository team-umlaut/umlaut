require 'hpricot'
class Amazon < Service
  required_config_params :url, :api_key
  attr_reader :url

  def service_types_generated
    return [ ServiceTypeValue['cover_image'], ServiceTypeValue['description'],
             ServiceTypeValue['highlighted_link'], ServiceTypeValue['subject'],
             ServiceTypeValue['similar_item'] ]
  end
  
  def handle(request)
    return request.dispatched(self, true) if request.referent.metadata["isbn"].blank?

    begin
    
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
        return request.dispatched(self, DispatchedService::FailedTemporary)
      end
      self.parse_response(request, http_response)
    rescue Exception => e
      return request.dispatched(self, DispatchedService::FailedFatal, e)
    end
    
    return request.dispatched(self, true)
  end
  
  def parse_response(request, http_response)
    aws = Hpricot(http_response.body)
    # extract and collect info from the xml    
    
    # if we get an error from Amazon, return now. 
    err = (aws/"/ItemLookupResponse/Items/Request/Errors/Error")
    raise Exception.new("Error from Amazon web service: " + err.to_s) if ! err.blank?
    
    asin = (aws/"/ItemLookupResponse/Items/Item/ASIN").inner_html
    # collect cover art urls
    ["small","medium","large"].each do | size |
      if (img = aws.at("/ItemLookupResponse/Items/Item/"+size.capitalize+"Image/URL"))
        request.add_service_response({:service=>self, :display_text => 'Cover Image',:key=>size, :url => img.inner_html, :service_data => {:asin => asin, :size => size }},[ServiceTypeValue[:cover_image]])
        # :value_string=>asin,
      end
    end               
    
    # get description
    if desc = (aws.at("/ItemLookupResponse/Items/Item/EditorialReviews/EditorialReview/Content"))
      request.add_service_response({:service=>self, :key=>'description', :value_string=>asin, :value_text=>desc.inner_html},['description'])
    end
    
    # we want to highlight Amazon to link to 'search in this book', etc.
    item_url = (aws.at("/ItemLookupResponse/Items/Item/DetailPageURL"))
    if item_url
      service_data = { :url => item_url.inner_html, :asin=>asin,
                       :display_text => "View at Amazon.com"}
                       request.add_service_response({:service=>self, :service_data=>service_data}, [ServiceTypeValue['highlighted_link']])

      #request.add_service_response({:service=>self,:key=>'url',:value_string=>asin, :value_text=>item_url.inner_html},[ServiceTypeValue['highlighted_link']]) if item_url
    end
    
    

    # gather Amazon's subject headings
    (aws/"/ItemLookupResponse/Items/Item/Subjects/Subject").each do |subject|
      request.add_service_response({:service=>self, :key=>'Amazon',:value_string=>asin,:value_alt_string=>subject.inner_html},['subject'])
    end
    
    # Get Amazon's 'similar products' to help recommend other useful items
    (aws/"/ItemLookupResponse/Items/Item/SimilarProducts/SimilarProduct").each do |similar|
      request.add_service_response({:service=>self,:key=>'book', :value_string=>(similar.at("/ASIN")).inner_html, :value_alt_string=>(similar.at("/Title")).inner_html},['similar_item'])
    end


    # Meta-data enhance
    item_attributes = aws.at("/itemlookupresponse/items/item/itemattributes")
    require 'ruby-debug'
    debugger
    
    request.referent.enhance_referent('format', 'book', false) unless request.referent.format == 'book'
    unless request.referent.metadata['btitle']
      if title = (item_attributes.at("/title"))
        request.referent.enhance_referent('btitle', title.inner_html)
      end
    end
    unless request.referent.metadata['au']
      if author = (item_attributes.at("/author"))
        request.referent.enhance_referent('au', author.inner_html)
      end
    end    
    unless request.referent.metadata['pub']
      if pub = (item_attributes.at("/publisher"))
        request.referent.enhance_referent('pub', pub.inner_html)
      end
    end      
    unless request.referent.metadata['tpages']
      if tpages = (item_attributes.at("/numberofpages"))
        request.referent.enhance_referent('tpages', tpages.inner_html)
      end
    end     
  end
end
