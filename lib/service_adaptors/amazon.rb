#
#   services.yml params include:
#   api_key:    required
#   load_cover_images:false    to suppress cover image loading. 
#
class Amazon < Service
  require 'hpricot'
  
  required_config_params :url, :api_key
  attr_reader :url

  def initialize(config)
    # defaults
    @display_name = "Amazon.com"
    @display_text = "Amazon's page"
    @load_cover_images = true
    super(config)
  end


  def service_types_generated
    types = [ ServiceTypeValue['abstract'],
             ServiceTypeValue['highlighted_link'], ServiceTypeValue['subject'],
             ServiceTypeValue['similar_item'] ]

    types.push( ServiceTypeValue['cover_image'] ) if @load_cover_images

    return types
  end
  
  def handle(request)    
    isbn = request.referent.metadata['isbn']
    # We're assuming the ISBN is the ASIN Amazon ID. Not neccesarily valid
    # assumption, but works enough of the time and there's no easy
    # alternative.
    # Clean up the isbn, and convert 13 to 10 if neccesary. 
    require 'isbn/tools'

    return request.dispatched(self, true) if isbn.blank?
    # remove hyphens and such

    
    isbn = isbn.gsub(/[^0-9X]/,'')
    if ( ISBN_Tools.is_valid_isbn13?( isbn ) )
      # got to try converting to 10. An ISBN-13 is never an ASIN. 
      isbn = ISBN_Tools.isbn13_to_isbn10(isbn)   
    end      
    
    return request.dispatched(self, true) if isbn.blank?

    begin
    
      # get the Amazon query
      
      query = "Service=AWSECommerceService&SubscriptionId=#{@api_key}&Operation=ItemLookup&ResponseGroup=Large,Subjects&ItemId="+isbn
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


    unless (err.blank?)
      if (err.at('code').inner_html == 'AWS.InvalidParameterValue')
        # Indicates an ISBN that Amazon doesn't know about, or that
        # was mal-formed. We can't tell the difference, so either
        # way let's silently ignore. 
        return
      else
        raise Exception.new("Error from Amazon web service: " + err.to_s)
      end
    end

    asin = (aws/"/ItemLookupResponse/Items/Item/ASIN").inner_html

    if ( @load_cover_images )
      # collect cover art urls
      ["small","medium","large"].each do | size |
        if (img = aws.at("/ItemLookupResponse/Items/Item/"+size.capitalize+"Image/URL"))
          request.add_service_response({:service=>self, :display_text => 'Cover Image',:key=>size, :url => img.inner_html, :service_data => {:asin => asin, :size => size }},[ServiceTypeValue[:cover_image]])
          # :value_string=>asin,
        end
      end
    end

    item_url = (aws.at("/ItemLookupResponse/Items/Item/DetailPageURL"))
    
    # get description
    if desc = (aws.at("/ItemLookupResponse/Items/Item/EditorialReviews/EditorialReview/Content"))

      # For some reason we need to un-escape the desc. Don't entirely get it.
      desc_text = CGI.unescapeHTML( desc.inner_text )
      
      request.add_service_response({:service=>self, :display_text => "Description from Amazon.com", :url => item_url.inner_html, :key=>'abstract', :value_string=>asin, :service_data => {:content=>desc_text }},['abstract'])
    end
    
    # we want to highlight Amazon to link to 'search in this book', etc.
    if item_url
      service_data = { :url => item_url.inner_html, :asin=>asin,
                       :display_text => @display_text }
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
    
    request.referent.enhance_referent('format', 'book', false) unless request.referent.format == 'book'
    unless request.referent.metadata['btitle']
      if title = (item_attributes.at("/title"))
        request.referent.enhance_referent('btitle', title.inner_html)
      end
    end
    unless (request.referent.metadata['au'] || request.referent.metadata["aulast"])
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
