#
#   services.yml params include:
#   api_key:    required
#   service_types: Optional. Array of strings of service type values to be
#                  loaded, to over-ride defaults.
#   make_aws_call:  default true.   If false, then assumes that a previous wave
#                     of services ran an amazon service adaptor
#                     and stored an asin in the referent. highlighted_link
#                     and search_inside can just use that asin and avoid
#                     another AWS call. Used to split amazon into
#                     two waves, since highlighted_link and cover_image
#                     calls require _another_ HTTP request to amazon
#                     and screen scrape.
#
#  See example of two-wave amazon in config/umlaut_distribution/services.yml-dist. 
#
class Amazon < Service
  require 'open-uri'
  require 'hpricot'
  include MetadataHelper
  
  required_config_params :url, :api_key
  attr_reader :url

  def initialize(config)
    # defaults
    @url = 'http://webservices.amazon.com/onca/xml'
    # This was somehow reverse engineered to get the full-page (non-lightbox)
    # reader url, which we prefer. Not sure if this will keep working forever,
    # don't entirely understand what's going on. 
    @reader_base_url = 'http://www.amazon.com/gp/sitbv3/reader/'
    # Ordinarly reader url, which often returns the weird 'lightboxed' version.
    #
    # @reader_base_url = "http://www.amazon.com/gp/reader/";
    @display_name = "Amazon.com"
    @display_text = "Amazon's page"
    @excerpts_display_text = "Excerpts"
    @service_types = ["abstract", "highlighted_link", "cover_image", "search_inside", "referent_enhance", "excerpts"]
    @make_aws_call = true
    
    super(config)

    # Only a few service types can get by without an aws call
    if (! @make_aws_call &&
          @service_types.find {|type|  ! ["search_inside", "highlighted_link", "excerpts"].include?(type) }  )
      raise Exception.new("You can only set make_aws_call == false on the definition of an Amazon service adaptor when the adaptor is also set to generate no service responses other than highlighted_link, search_inside, and excerpts")
    end
  end


  def service_types_generated
    types = Array.new

    @service_types.each do |type|
      types.push( ServiceTypeValue[type])
    end
    
    return types
  end
  
  def handle(request)
    
    isbn = request.referent.metadata['isbn']
    isbn = isbn.gsub(/[^0-9X]/,'') if isbn

    return request.dispatched(self, true) if isbn.blank?

    begin

      selected_aws_vals = {}
      if ( @make_aws_call )
        aws_response = make_aws_request( isbn )
        
        return request.dispatched(self, true) if aws_response.blank?
  
        # Add service responses based on AWS response
        selected_aws_vals = 
          self.add_aws_service_responses(request, aws_response)
      end

      if ( selected_aws_vals == nil)
        # no aws found.
        return request.dispatched(self, true)
      end
      
      # Add service responses based on ASIN--may be run in a
      # later service wave. Look up asin in db if we don't have
      # it from current service exec. 
      asin = selected_aws_vals[:asin] || 
          get_identifier(:urn, "asin", request.referent)
          
      self.add_asin_service_responses(request, asin, selected_aws_vals[:item_url])
      
    rescue TimeoutError
      # Try again later if we timeout; temporary error condition. 
      return request.dispatched(self, DispatchedService::FailedTemporary)    
    rescue Exception => e
      # Unexpected error, fatal error condition. 
      return request.dispatched(self, DispatchedService::FailedFatal, e)
    end
    
    return request.dispatched(self, true)
  end

  def make_aws_request(isbn)
    # We're assuming the ISBN is the ASIN Amazon ID. Not neccesarily valid
    # assumption, but works enough of the time and there's no easy
    # alternative.
    # Convert 13 to 10 if neccesary. 
    require 'isbn/tools'    
    if ( ISBN_Tools.is_valid_isbn13?( isbn ) )
      # got to try converting to 10. An ISBN-13 is never an ASIN. 
      isbn = ISBN_Tools.isbn13_to_isbn10(isbn)   
    end  
    
    query = "Service=AWSECommerceService&SubscriptionId=#{@api_key}&Operation=ItemLookup&ResponseGroup=Large,Subjects&ItemId="+isbn
    uri = URI.parse(self.url+'?'+query)
    # send the request
    http = Net::HTTP.new(uri.host, 80)  
    http.open_timeout = 5
    http.read_timeout = 5
    http_response = http.send_request('POST', uri.path + '?' + uri.query)    
    
    return http_response
  end
  
  def add_aws_service_responses(request, aws_response)
    return_hash = Hash.new
    
    aws = Hpricot(aws_response.body)
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

    # Store the asin in the referent as non-metadata private data, so
    # a future background service can use it. Store as a urn identifier.
    request.referent.enhance_referent("identifier", "urn:asin:#{asin}", false, false) unless asin.blank?
    return_hash[:asin] = asin

    if ( @service_types.include?("cover_image") )
      # collect cover art urls
      ["small","medium","large"].each do | size |
        if (img = aws.at("/ItemLookupResponse/Items/Item/"+size.capitalize+"Image/URL"))
          request.add_service_response({:service=>self, :display_text => 'Cover Image',:key=>size, :url => img.inner_html, :service_data => {:asin => asin, :size => size }},[ServiceTypeValue[:cover_image]])
          # :value_string=>asin,
        end
      end
      
    end

    item_url = (aws.at("/ItemLookupResponse/Items/Item/DetailPageURL")).inner_html
    # Store to return to caller
    return_hash[:item_url] = item_url

    
    # get description
    if (  @service_types.include?("abstract") &&
         desc =
         (aws.at("/ItemLookupResponse/Items/Item/EditorialReviews/EditorialReview/Content")))

      # For some reason we need to un-escape the desc. Don't entirely get it.
      desc_text = CGI.unescapeHTML( desc.inner_text )

      unless ( desc_text.blank? )
        request.add_service_response({:service=>self, :display_text => "Description from Amazon.com", :url => item_url, :key=>'abstract', :value_string=>asin, :service_data => {:content=>desc_text }},['abstract'])
      end
    end
    
        
    
    if ( @service_types.include?("subject"))
      # gather Amazon's subject headings
      (aws/"/ItemLookupResponse/Items/Item/Subjects/Subject").each do |subject|
        request.add_service_response({:service=>self, :key=>'Amazon',:value_string=>asin,:value_alt_string=>subject.inner_html},['subject'])
      end
    end

    if ( @service_types.include?("similar_item"))
      # Get Amazon's 'similar products' to help recommend other useful items
      (aws/"/ItemLookupResponse/Items/Item/SimilarProducts/SimilarProduct").each do |similar|
        request.add_service_response({:service=>self,:key=>'book', :value_string=>(similar.at("/ASIN")).inner_html, :value_alt_string=>(similar.at("/Title")).inner_html},['similar_item'])
      end

   end


    if ( @service_types.include?("referent_enhance"))
      item_attributes = aws.at("/itemlookupresponse/items/item/itemattributes")
      
      request.referent.enhance_referent('format', 'book', false) unless request.referent.format == 'book'
      unless request.referent.metadata['btitle']
        if title = (item_attributes.at("/title"))
          request.referent.enhance_referent('btitle', title.inner_html)
        end

      end
			# Enhance with full author name string even if aulast is already present, because full string may be useful for worldcat identities. 
      unless (request.referent.metadata['au'] )
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

    return return_hash
  end

  def add_asin_service_responses(request, asin, item_url)
    # we want to highlight Amazon to link to 'search in this book', etc.
    if asin
      # Search or Look inside the book offered? We only know by trying and
      # then screen-scraping.
      search_inside = false
      look_inside = false

      # Check for search_inside or look_inside if we're configured
      # to supply highlighted_link or search_inside, that's what we
      # need it for.
      if ( @service_types.include?("highlighted_link") ||
           @service_types.include?("search_inside"))
        inside_base = @reader_base_url + asin
        # lame screen-scrape for search inside availability. We need to
        # distinguish between no results, "look inside", and "search inside".
        response = open(inside_base).read

        # This regexp only suitable for screen-scraping the old-style "sitbv3"
        # reader page screen
        if ( response =~ /\<option[^>]*\>Inside this Book\<\/option\>/ )
          # search_inside implies look_inside too. 
          search_inside= true
          look_inside = true
        elsif (not (response =~ /book is temporarily unavailable/))
          # No search inside, but I think we have look inside.
          # Provide a "see also" link direct to look inside
          look_inside = true
        end
      end

      if ( @service_types.include?("search_inside") && search_inside )
        request.add_service_response( 
          {:service => self,
          :display_text=>@display_name,
          :url=> inside_base},
          [:search_inside]
         )   
      end

      # Link to look inside if we have it, otherwise ordinary amazon detail
      # page. 

      if (@service_types.include?("excerpts") &&
          ( search_inside || look_inside ))
        service_data = { :url => inside_base, :asin=>asin,
           :display_text => @display_name }
                         
         request.add_service_response({:service=>self, :service_data=>service_data}, [ServiceTypeValue['excerpts']])
      elsif ( @service_types.include?("highlighted_link"))
          # Just link to Amazon page if we can. If we did the AWS request
          # before, afraid we didn't store the item url, just the
          # asin, reconstruct a valid one, even if not the one given to us
          # by AWS. 
          amazon_page = item_url || ("http://www.amazon.com/o/ASIN/" + asin)
          service_data = { :url => amazon_page, :asin=>asin,
                         :display_text => @display_text }
                         
          request.add_service_response({:service=>self, :service_data=>service_data}, [ServiceTypeValue['highlighted_link']])
      end
      
    end

  end
  
  # Catch url_for call for search_inside, because we're going to redirect
  def response_url(service_type, submitted_params)
    if ( ! (service_type.service_type_value.name == "search_inside" ))
      return super(service_type, submitted_params)
    else
      # search inside!
      base = service_type.service_response[:url]
      query = CGI.escape(submitted_params["query"] || "")
      url = base + "/ref=sib_dp_srch_pop?v=search-inside&keywords=#{query}&go=Go%21"
      return url
    end
  end

  
end
