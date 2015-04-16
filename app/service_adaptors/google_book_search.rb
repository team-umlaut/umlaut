# Service that searches Google Book Search to determine viewability.
# It searches by ISBN, OCLCNUM and/or LCCN. 
#
# Uses Google Books API, http://code.google.com/apis/books/docs/v1/getting_started.html 
# http://code.google.com/apis/books/docs/v1/using.html
# 
# If a full view is available it returns a fulltext service response.
# If partial view is available, return as "limited experts". 
# If no view at all, still includes a link in highlighted_links, to pay
#   lip service to google branding requirements. 
# Unfortunately there is no way tell which of the noview 
# books provide search, although some do -- search is advertised if full or 
# partial view is available. 
# 
# If a thumbnail_url is returned in the responses, a cover image is displayed.
#
# Can also enhances with an abstract, if available. -- off by default, set `abstract: true` to turn on.  
#
# And fleshes out bibliographic details from an identifier -- if all you had was an
# ISBN, will fill in title, author, etc in referent from GBS response.  
#
# = Google API Key
# 
# Setting an api key in :api_key STRONGLY recommended, or you'll
# probably get rate limited (not clear what the limit is with no api
# key supplied). You may have to ask for higher rate limit for your api
# key than the default 1000/day, which you can do through the google 
# api console:
# https://code.google.com/apis/console
#
# I requested 50k with this message, and was quickly approved with no questions
# "Services for academic library (Johns Hopkins Libraries) web applications  to match Google Books availability to items presented by our catalog, OpenURL link resolver,  and other software. "
#
# Recommend setting your 'per user limit' to something crazy high, as well
# as requesting more quota. 
class GoogleBookSearch < Service
  require 'multi_json'
  
  
  # Identifiers used in API response to indicate viewability level
  ViewFullValue = 'ALL_PAGES'
  ViewPartialValue = 'PARTIAL'
  # None might also be 'snippet', but Google doesn't want to distinguish
  ViewNoneValue = 'NO_PAGES'
  ViewUnknownValue = 'UNKNOWN'
      
  
  
  include MetadataHelper
  include UmlautHttp
  
  # required params
  
  # attr_reader is important for tests
  attr_reader :url, :display_name, :num_full_views 
  
  def service_types_generated
    types= []

    if @web_links
      types.push ServiceTypeValue[:highlighted_link]
      types.push ServiceTypeValue[:excerpts]
    end
    types.push(ServiceTypeValue[:search_inside]) if @search_inside
    types.push(ServiceTypeValue[:fulltext]) if @fulltext
    types.push(ServiceTypeValue[:cover_image]) if @cover_image
    types.push(ServiceTypeValue[:referent_enhance]) if @referent_enhance
    types.push(ServiceTypeValue[:abstract]) if @abstract

    return types
  end
  
  def initialize(config)    
    @url = 'https://www.googleapis.com/books/v1/volumes?q='
    
    @display_name = 'Google Books'
    
    # number of full views to show
    @num_full_views = 1
    
    # default on, to enhance our metadata with stuff from google
    @referent_enhance = true

    # default OFF, add description/abstract from GBS
    @abstract = false

    # Other responses on by default but can be turned off
    @cover_image   = true
    @fulltext      = true
    @search_inside = true
    @web_links     = true # to partial view :excerpts or :fulltext

    # google api key strongly recommended, otherwise you'll
    # probably get rate limited. 
    @api_key = nil
    
    @credits = {
      "Google Books" => "http://books.google.com/"
    }
    # While you can theoretically look up by LCCN on Google Books,
    # we have found FREQUENT false positives. There's no longer any
    # way to even report these to Google. By default, don't lookup
    # by LCCN. 
    @lookup_by_lccn = false
    
    super(config)
  end
  
  def handle(request)

    bibkeys = get_bibkeys(request.referent)
    return request.dispatched(self, true) if bibkeys.nil?

    data = do_query(bibkeys, request)
    
    
    if data.blank? || data["error"]
      # fail fatal
      return request.dispatched(self, false)
    end
    
    # 0 hits, return. 
    return request.dispatched(self, true) if data["totalItems"] == 0
    
    enhance_referent(request, data) if @referent_enhance

    add_abstract(request, data) if @abstract
    
    #return full views first
    if @fulltext
      full_views_shown = create_fulltext_service_response(request, data)
    end
    
    if @search_inside
      # Add search_inside link if appropriate
      add_search_inside(request, data)
    end
    
    # only if no full view is shown, add links for partial view or noview
    unless full_views_shown
      do_web_links(request, data)
    end
    
    if @cover_image
      thumbnail_url = find_thumbnail_url(data)
      if thumbnail_url
        add_cover_image(request, thumbnail_url)    
      end
    end

    return request.dispatched(self, true)
  end

  # Take the FIRST hit from google, and use it's values to enhance
  # our metadata. Will NOT overwrite existing data. 
  def enhance_referent(request, data)
    
    entry = data["items"].first
    

    if (volumeInfo = entry["volumeInfo"])
      
      title = volumeInfo["title"]
      title += ": #{volumeInfo["subtitle"]}" if (title && volumeInfo["subtitle"])
      
      element_enhance(request, "title", title)
      element_enhance(request, "au", volumeInfo["authors"].first) if volumeInfo["authors"]
      element_enhance(request, "pub", volumeInfo["publisher"])
      
      element_enhance(request, "tpages", volumeInfo["pageCount"])
      
      if (date = volumeInfo["publishedDate"]) && date =~ /^(\d\d\d\d)/
        element_enhance(request, "date", $1)
      end
      
      # LCCN is only rarely included, but is sometimes, eg:
      # "industryIdentifiers"=>[{"type"=>"OTHER", "identifier"=>"LCCN:72627172"}],          
      # Also "LCCN:76630875"
      #
      # And sometimes OCLC number like:
      # "industryIdentifiers"=>[{"type"=>"OTHER", "identifier"=>"OCLC:12345678"}],
      #        
      (volumeInfo["industryIdentifiers"] || []).each do |hash|
        
        if hash["type"] == "ISBN_13"
          element_enhance(request, "isbn", hash["identifier"])
          
        elsif hash["type"] == "OTHER" && hash["identifier"].starts_with?("LCCN:")
          lccn = normalize_lccn(  hash["identifier"].slice(5, hash["identifier"].length)  )
          request.referent.add_identifier("info:lccn/#{lccn}")
          
        elsif hash["type"] == "OTHER" && hash["identifier"].starts_with?("OCLC:")
          oclcnum = normalize_lccn(  hash["identifier"].slice(5, hash["identifier"].length)  )
          request.referent.add_identifier("info:oclcnum/#{oclcnum}")
        end
      
      end              
    end            
  end

  def add_abstract(request, data)
    info = data["items"].first.try {|h| h["volumeInfo"]}
    if description = info["description"]

      url = info["infoLink"]
      request.add_service_response(
          :service => self, 
          :display_text => "Description from Google Books", 
          :display_text_i18n => "description",
          :url => remove_query_context(url),
          :service_type_value =>  :abstract  
      )
    end
  end

  # Will not over-write existing referent values. 
  def element_enhance(request, rft_key, value)
    if (value)
      request.referent.enhance_referent(rft_key, value.to_s, true, false, :overwrite => false)
    end
  end

  
  # returns nil or escaped string of bibkeys
  # to increase the chances of good hit, we send all available bibkeys 
  # and later dedupe by id.
  # FIXME Assumes we only have one of each kind of identifier.
  def get_bibkeys(rft)
    isbn = get_identifier(:urn, "isbn", rft)
    oclcnum = get_identifier(:info, "oclcnum", rft)
    lccn = get_lccn(rft)

    # Google doesn't officially support oclc/lccn search, but does
    # index as token with prefix smashed up right with identifier
    # eg http://books.google.com/books/feeds/volumes?q=OCLC32012617
    #
    # Except turns out doing it as a phrase search is important! Or
    # google's normalization/tokenization does odd things. 
    keys = []
    keys << ('isbn:' + isbn) if isbn
    keys << ('"' + "OCLC" + oclcnum + '"') if oclcnum
    # Only use LCCN if we've got nothing else, and we're allowing it. 
    # it returns many false positives. 
    if @lookup_by_lccn && lccn && keys.length == 0
      keys << ('"' + 'LCCN' + lccn + '"')
    end
    
    return nil if keys.empty?
    keys = CGI.escape( keys.join(' OR ') )
    return keys
  end
  
  def do_query(bibkeys, request)    
    headers = build_headers(request)
    link = @url + bibkeys
    if @api_key
      link += "&key=#{@api_key}"
    end
    
    # Add on limit to only request books, not magazines. 
    link += "&printType=books"

    Rails.logger.debug("GoogleBookSearch requesting: #{link}")        
    response = http_fetch(link, :headers => headers, :raise_on_http_error_code => false)        
    data = MultiJson.load(response.body)
    
    # If Google gives us an error cause it says it can't geo-locate, 
    # remove the IP, log warning, and try again. 
    
    if (data["error"] && data["error"]["errors"] &&
        data["error"]["errors"].find {|h| h["reason"] == "unknownLocation"} )
      Rails.logger.warn("GoogleBookSearch: geo-locate error, retrying without X-Forwarded-For: '#{link}' headers: #{headers.inspect} #{response.inspect}\n    #{data.inspect}")
      
      response = http_fetch(link, :raise_on_http_error_code => false)        
      data = MultiJson.load(response.body)
        
    end
    
    
    if (! response.kind_of?(Net::HTTPSuccess)) || data["error"]      
      Rails.logger.error("GoogleBookSearch error: '#{link}' headers: #{headers.inspect} #{response.inspect}\n    #{data.inspect}")
    end
        
    return data
  end
  
  # We don't need to fake a proxy request anymore, but we still
  # include X-Forwarded-For so google can return location-appropriate
  # availability. If there's an existing X-Forwarded-For, we respect
  # it and add on to it. 
  def build_headers(request)
    original_forwarded_for = nil
    if (request.http_env && request.http_env['HTTP_X_FORWARDED_FOR'])
      original_forwarded_for = request.http_env['HTTP_X_FORWARDED_FOR']                                  
    end

    # we used to prepare a comma seperated list in x-forwarded-for if
    # we had multiple requests, as per the x-forwarded-for spec, but I
    # think Google doesn't like it. 
    
    ip_address = (original_forwarded_for ?
        original_forwarded_for  :
        request.client_ip_addr.to_s)
    
    return {} if ip_address.blank?

    # If we've got a comma-seperated list from an X-Forwarded-For, we
    # can't send it on to google, google won't accept that, just take
    # the first one in the list, which is actually the ultimate client
    # IP. split returns the whole string if seperator isn't found, convenient.
    ip_address = ip_address.split(",").first
    
    # If all we have is an internal/private IP from the internal network,
    # do NOT send that to Google, or Google will give you a 503 error
    # and refuse to process your request, as of 7 sep 2011. sigh.
    # Also if it doesn't look like an IP at all, forget it, don't send it.     
    if ((! ip_address =~ /^\d+\.\d+\.\d+\/\d$/) || 
       ip_address.start_with?("10.") || 
       ip_address.start_with?("172.16") || 
       ip_address.start_with?("192.168"))
       return {}
    else    
      return {'X-Forwarded-For' => ip_address }
    end
  end
  
  def find_entries(gbs_response, viewabilities)
    unless (viewabilities.kind_of?(Array))
      viewabilities = [viewabilities]
    end

    entries = gbs_response["items"].find_all do |entry|
      viewability = entry["accessInfo"]["viewability"]
      (viewability && viewabilities.include?(viewability))           
    end

    return entries
  end
  
  
  # We only create a fulltext service response if we have a full view.
  # We create only as many full views as are specified in config.
  def create_fulltext_service_response(request, data)
    full_views = find_entries(data, ViewFullValue)
    return nil if full_views.empty?
    
    count = 0
    full_views.each do |fv|
      
      uri = fv["volumeInfo"]["previewLink"]
          
      request.add_service_response(
          :service => self, 
          :display_text => @display_name, 
          :display_text_i18n => "display_name",
          :url => remove_query_context(uri),           
          :service_type_value =>  :fulltext  
      )
      count += 1
      break if count == @num_full_views
    end   
    return true
  end

  def add_search_inside(request, data)
    # Just take the first one we find, if multiple
    searchable_view = find_entries(data, [ViewFullValue, ViewPartialValue])[0]        
    
    if ( searchable_view )
      url = searchable_view["volumeInfo"]["infoLink"]
      
      request.add_service_response( 
        :service => self,
        :display_text=>@display_name,
        :display_text_i18n => "display_name",
        :url=> remove_query_context(url),
        :service_type_value => :search_inside
       )                  
    end
    
  end
  
  # create highlighted_link service response for partial and noview
  # Only show one web link. prefer a partial view over a noview.
  # Some noviews have a snippet/search, but we have no way to tell. 
  def do_web_links(request, data)

    # some noview items will have a snippet view, but we have no way to tell
    info_views = find_entries(data, ViewPartialValue)
    viewability = ViewPartialValue
    
    if info_views.blank?
      info_views = find_entries(data, ViewNoneValue)
      viewability = ViewNoneValue  
    end
    
    # Shouldn't ever get to this point, but just in case
    return nil if info_views.blank?
    
    url = ''
    iv = info_views.first
    type = nil
    if (viewability == ViewPartialValue && 
        url = iv["volumeInfo"]["previewLink"])
      url = fix_pg_gbs_link(url)
      display_text = @display_name
      display_text_i18n = "display_name"
      type = ServiceTypeValue[:excerpts]
    else
      url = iv["volumeInfo"]["infoLink"]
      url = fix_pg_gbs_link(url)
      display_text = "Book Information"
      display_text_i18n = "book_information"
      type = ServiceTypeValue[:highlighted_link]
    end


    request.add_service_response( 
        :service=>self,    
        :url=> remove_query_context(url),
        :display_text=>display_text,
        :display_text_i18n => display_text_i18n,
        :service_type_value => type    
     )
  end
  
  # google books direct links do weird things with linking to
  # internal pages, perhaps intending to be based on our
  # search criteria, which pages matched, but we're not
  # using it like that for links to excerpts or full page. 
  # reverse engineer it to go to full page. 
  def fix_pg_gbs_link(url)
    url.sub(/([\?\;\&])(pg=[^;&]+)/, '\1pg=1')
  end

  
 
  # Not all responses have a thumbnail_url. We look for them and return the 1st.
  def find_thumbnail_url(data)
    entries = data["items"].collect do |entry|      
      entry["volumeInfo"]["imageLinks"]["thumbnail"] if entry["volumeInfo"] && entry["volumeInfo"]["imageLinks"]      
    end
    
    # removenill values
    entries.compact!    
    
    # pick the first of the available thumbnails, or nil
    return entries[0]
  end
  

  def add_cover_image(request, url)
    zoom_url = url.clone
    
    # if we're sent to a page other than the frontcover then strip out the
    # page number and insert front cover
    zoom_url.sub!(/&pg=.*?&/, '&printsec=frontcover&')
    
    # hack out the 'curl' if we can
    zoom_url.sub!('&edge=curl', '')
    
    request.add_service_response(
        :service=>self, 
        :display_text => 'Cover Image',
        :url => zoom_url, 
        :size => "medium",
        :service_type_value => :cover_image
    )     
  end
  
  # Google gives us URL to the book that contains a 'dq' param
  # with the original query, which for us is an ISSN/LCCN/OCLCnum query,
  # which we don't actually want to leave in there. 
  def remove_query_context(url)
    url.sub(/&dq=[^&]+/, '')    
  end

  # Catch url_for call for search_inside, because we're going to redirect
  def response_url(service_response, submitted_params)
    if ( ! (service_response.service_type_value.name == "search_inside" ))
      return super(service_response, submitted_params)
    else
      # search inside!
      base = service_response[:url]
      query = CGI.escape(submitted_params["query"] || "")
      # attempting to reverse engineer a bit to get 'snippet'
      # style results instead of 'onepage' style results. 
      # snippet seem more user friendly, and are what google's own
      # interface seems to give you by default. but 'onepage' is the
      # default from our deep link, but if we copy the JS hash data,
      # it looks like we can get Google to 'snippet'.       
      url = base + "&q=#{query}#v=snippet&q=#{query}&f=false"
      return url
    end
  end
  
end

# Important to quote search, see: "OCLC1246014"

# Test WorldCat links
# FIXME: This produces two 'noview' links because the ids don't match.
#   This might be as good as we can do though, unless we want to only ever show
#   one 'noview' link. Notice that the metadata does differ between the two.
# http://localhost:3000/resolve?url_ver=Z39.88-2004&rfr_id=info%3Asid%2Fworldcat.org%3Aworldcat&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook&req_dat=%3Csessionid%3E&rft_id=info%3Aoclcnum%2F34576818&rft_id=urn%3AISBN%3A9780195101386&rft_id=urn%3AISSN%3A&rft.aulast=Twain&rft.aufirst=Mark&rft.auinitm=&rft.btitle=The+prince+and+the+pauper&rft.atitle=&rft.date=1996&rft.tpages=&rft.isbn=9780195101386&rft.aucorp=&rft.place=New+York&rft.pub=Oxford+University+Press&rft.edition=&rft.series=&rft.genre=book&url_ver=Z39.88-2004
#
# Snippet view returns noview through the API
# http://localhost:3000/resolve?rft.isbn=0155374656
#
# full view example, LCCN 07020699  ; OCLC: 1246014
