class Amazon < Service
  require 'hpricot'
  def handle(request)
    return request.dispatched(self, true) unless request.referent.metadata["isbn"]
    # get the Amazon query
    query = 'Service=AWSECommerceService&SubscriptionId='+self.password+'&Operation=ItemLookup&ResponseGroup=Large,Subjects&ItemId='+request.referent.metadata["isbn"].gsub(/[^0-9X]/,'')           
    uri = URI.parse(self.url+'?'+query)
    links = []
    # send the request
    http = Net::HTTP.new(uri.host, 80)  
    http_response = http.send_request('POST', uri.path + '?' + uri.query)    
    aws = Hpricot(http_response.body)
    # extract and collect info from the xml    

    # if we get an error from Amazon, just return
    return request.dispatched(self, true) if err = (aws/"/ItemLookupResponse/Items/Request/Errors/Error")
    asin = (aws/"/ItemLookupResponse/Items/Item/ASIN").inner_html
    # collect cover art urls
    if sm = (aws/"/ItemLookupResponse/Items/Item/SmallImage/URL")
      if svc_resp = self.service_responses.find(:first, :conditions=>["key = ? AND value_string = ?", 'small', asin])
        svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'image') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'image'])        
      else
        svc_resp = self.service_responses.create(:key=>'small',:value_string=>asin, :value_text=>sm.inner_html)
        request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'image')
      end	                
    end
    if med = (aws/"/ItemLookupResponse/Items/Item/MediumImage/URL")    
      if svc_resp = self.service_responses.find(:first, :conditions=>["key = ? AND value_string = ?", 'medium', asin])
        svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'image') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'image'])        
      else
        svc_resp = self.service_responses.create(:key=>'medium',:value_string=>asin, :value_text=>med.inner_html)
        request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'image')
      end	
    end       
    
    if lg = (aws/"/ItemLookupResponse/Items/Item/LargeImage/URL")    
      if svc_resp = self.service_responses.find(:first, :conditions=>["key = ? AND value_string = ?", 'large', asin])
        svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'image') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'image'])        
      else
        svc_resp = self.service_responses.create(:key=>'large',:value_string=>asin, :value_text=>lg.inner_html)
        request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'image')
      end	
    end                     
    
    # get description
    if desc = (aws/"/ItemLookupResponse/Items/Item/EditorialReviews/EditorialReview/Content")
      if svc_resp = self.service_responses.find(:first, :conditions=>["key = ? AND value_string = ?", 'description', asin])
        svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'abstract') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'abstract'])        
      else
        svc_resp = self.service_responses.create(:key=>'description',:value_string=>asin, :value_text=>desc.inner_html)
        request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'description')
      end	
    end
    
    # we want to highlight Amazon to link to 'search in this book', etc.
    item_url = (aws/"ItemLookupResponse/Items/Item/DetailPageURL")
    if svc_resp = self.service_responses.find(:first, :conditions=>["key = ? AND value_string = ?", 'url', asin])
      svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'highlighted_link') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'highlighted_link'])        
    else
      svc_resp = self.service_responses.create(:key=>'url',:value_string=>asin, :value_text=>item_url.inner_html)
      request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'highlighted_link')
    end	
    # gather Amazon's subject headings
    (aws/"/ItemLookupResponse/Items/Item/Subjects/Subject").each do |subject|
      if svc_resp = self.service_responses.find(:first, :conditions=>["key = ? AND value_string = ?", 'Amazon', subject.inner_html])
        svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'subject') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'subject'])        
      else
        svc_resp = self.service_responses.create(:key=>'Amazon',:value_string=>subject.inner_html)
        request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'subject')
      end	
    end
    
    # Get Amazon's 'similar products' to help recommend other useful items
    (aws/"/ItemLookupResponse/Items/Item/SimilarProducts/SimilarProduct").each do |similar|
      if svc_resp = self.service_responses.find(:first, :conditions=>["key = ? AND value_string = ? AND value_alt_string = ?", 'book', (similar/"/ASIN").inner_html, (similar/"/Title").inner_html])
        svc_type = request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'similar_item') unless request.service_types.find(:first, :conditions=>["service_response_id = ? AND service_type = ?", svc_resp.id, 'similar_item'])        
      else
        svc_resp = self.service_responses.create(:key=>'book',:value_string=>(similar/"/ASIN").inner_html, :value_alt_string=>(similar/"/Title").inner_html)
        request.service_types.create(:service_response_id=>svc_resp.id, :service_type=>'subject')
      end      
      co = OpenURL::ContextObject.new
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
