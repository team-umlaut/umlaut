#
#   As of Aug 15 2009, Amazon API calls will require a secret key from Amazon.
#   If you are unable to get such an account/key, this service can still be used
#   for certain functions by setting 'make_aws_call' to false, and configuring
#   'service_types' to only include one or more of:  ["search_inside",
#   "highlighted_link", "excerpts"]
#   Other services, such as enhance_referent and cover_image require api access.
#
#   More about registering for and finding your AWS access key and secret key
#   can be found here:
# http://docs.amazonwebservices.com/AWSECommerceService/latest/DG/AWSCredentials.html
# http://docs.amazonwebservices.com/AWSECommerceService/latest/DG/ViewingCredentials.html
#
#
#   services.yml params:
#   api_key:    required. AWS "access key". 
#   secret_key:  required unless make_aws_call==false. AWS "secret access key". 
#   associate_tag: required unless make_aws_call==false. Now required by Amazon API. 
#                  sign up for an associates_id at: https://affiliate-program.amazon.com/
#                  it's the same thing as your 'associate id'. 
#   service_types: Optional. Array of strings of service type values to be
#                  loaded, to over-ride defaults.
#   make_aws_call:  default true.   If false, then either uses an ASIN stored
#                     in referent from previous service, or tries assuming
#                     that an ISBN, if present, is the ASIN. 
#                     of services ran an amazon service adaptor
#                     Can be used to split amazon into
#                     two waves, since highlighted_link and cover_image
#                     calls require _another_ HTTP request to amazon
#                     and screen scrape. Or can be used if you don't
#                     have access to Amazon API. 
#
#  See example of two-wave amazon in config/umlaut_distribution/services.yml-dist. 
#
class Amazon < Service
  require 'open-uri'
  require 'hpricot'
  require 'isbn'
  
  
  include MetadataHelper
  
  required_config_params :url, :api_key, :associate_tag
  attr_reader :url

  def initialize(config)
    # defaults
    @url = 'http://webservices.amazon.com/onca/xml'     
    @reader_base_url = 'http://www.amazon.com/gp/reader/'
    # Old version non-lightboxed, whcih doesn't work very well anymore.     
    # @reader_base_url = 'http://www.amazon.com/gp/sitbv3/reader/'
    @display_name = "Amazon.com"
    @display_text = "Amazon's page"
    @service_types = ["abstract", "highlighted_link", "cover_image", "search_inside", "referent_enhance", "excerpts"]
    @make_aws_call = true
    @http_timeout = 5
    
    super(config)

    # Need the secret_key after 15 aug 09.
    unless (@secret_key || ! @make_aws_call)
      if ( Time.now < Time.gm(2009, 8, 15))
        Rails.logger.warn("Amazon service will require a secret_key after 15 August 2009 to make Amazon API calls.")
      else
        raise Exception.new("Amazon API now requires a secret_key. The Amazon service can only be used with make_aws_call=false unless you have an Amazon secret key configured.")
      end
    end

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
    
    # got to try converting to 10. An ISBN-13 is never an ASIN.    
    isbn = ISBN.ten( isbn )
              

    query_params = {
      "Service"=>"AWSECommerceService",
      "AWSAccessKeyId"=>@api_key,
      "AssociateTag"=>@associate_tag,
      "Operation"=>"ItemLookup",
      "ResponseGroup"=>"Large",
      "ItemId"=>isbn }
    
    # has to be signed
    query = nil

    if ( @secret_key )
      aws = AwsProductSign.new(:access_key => @api_key, 
                               :secret_key => @secret_key )
      query = aws.query_with_signature( query_params )
    else
      query = query_params.collect {|key, value| CGI.escape(key) + '=' + CGI.escape(value)}.join("&")
    end
      
    uri = URI.parse(self.url+'?'+query)
    # send the request
    http = Net::HTTP.new(uri.host, 80)  
    http.open_timeout = @http_timeout
    http.read_timeout = @http_timeout
    http_response = http.send_request('GET', uri.path + '?' + uri.query)    
    
    return http_response
  end
  
  def add_aws_service_responses(request, aws_response)
    return_hash = Hash.new
    
    aws = Hpricot(aws_response.body)
    # extract and collect info from the xml    
    
    # if we get an error from Amazon, return now. 
    err = (aws/"/ItemLookupResponse/Items/Request/Errors/Error")
    err = (aws/"/ItemLookupErrorResponse") if err.blank?
    
    unless (err.blank?)
      if (err.at('code').inner_text == 'AWS.InvalidParameterValue')
        # Indicates an ISBN that Amazon doesn't know about, or that
        # was mal-formed. We can't tell the difference, so either
        # way let's silently ignore. 
        return
      else
        raise Exception.new("Error from Amazon web service: " + err.to_s)
      end
    end

    asin = (aws/"/ItemLookupResponse/Items/Item/ASIN").inner_text

    # Store the asin in the referent as non-metadata private data, so
    # a future background service can use it. Store as a urn identifier.
    request.referent.add_identifier("urn:asin:#{asin}") unless asin.blank?

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
    

    if ( @service_types.include?("similar_item"))
      # Get Amazon's 'similar products' to help recommend other useful items
      (aws/"/ItemLookupResponse/Items/Item/SimilarProducts/SimilarProduct").each do |similar|
        request.add_service_response({:service=>self,:key=>'book', :value_string=>(similar.at("/ASIN")).inner_text, :value_alt_string=>(similar.at("/Title")).inner_text},['similar_item'])
      end

   end


    if ( @service_types.include?("referent_enhance"))
      item_attributes = aws.at("/itemlookupresponse/items/item/itemattributes")
      
      request.referent.enhance_referent('format', 'book', false) unless request.referent.format == 'book'
      metadata = request.referent.metadata
      unless (metadata['btitle'] || metadata['title'])
        if title = (item_attributes.at("/title"))
          request.referent.enhance_referent('btitle', normalize_aws_title(title.inner_text))
        end

      end
			# Enhance with full author name string even if aulast is already present, because full string may be useful for worldcat identities. 
      unless (metadata['au'] )
        if author = (item_attributes.at("/author"))
          request.referent.enhance_referent('au', author.inner_text)
        end
      end

      unless metadata['pub']
        if pub = (item_attributes.at("/publisher"))
          request.referent.enhance_referent('pub', pub.inner_text)
        end
      end      
      unless metadata['tpages']
        if tpages = (item_attributes.at("/numberofpages"))
          request.referent.enhance_referent('tpages', tpages.inner_text)
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
        if (response.include?("<div class='sitb-pop-search'>"))
          # then we have search_inside. I think this always includes 'look', but
          # we'll test seperate for that. 
          search_inside= true
        end
        
        if (response.include?('<a href="/gp/reader/'))
          # then we have look inside, not neccesarily search.  
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

  #amazon is in the habit of including things in parens at the end
  #of the title that aren't really part of the title. The parens
  # are really an edition and/or series statement. We have nowhere
  # good to store that. 
  def normalize_aws_title(title)
    title.sub(/\([^)]*\)\s*$/, '')
  end

  
end

# Example of no look or search:
# www.amazon.com/gp/reader/0794521789

# Example of look and search:
# http://www.amazon.com/gp/reader/1851960511

# Example of 'look inside' with no search:
# http://www.amazon.com/gp/reader/0140441115/

# Scraping /gp/reader page. 

# Only look inside (preview) if link like:
# <a href="/gp/reader/1851960511/ref=sib_dp_pop_sup?ie=UTF8&amp;p=random#reader-link
# OR:
# <a href="/gp/reader/0140441115/ref=sib_dp_kd#reader-link" onclick="if (typeof(SitbReader) != 'undefined')


# Only search inside if:

# '<td class="tinypopup">Search Inside This Book:</td>'
# OR: <div class='sitb-pop-search'> 

