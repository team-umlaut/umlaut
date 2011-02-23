# Service that searches Google Book Search to determine viewability.
# It searches by ISBN, OCLCNUM and LCCN. If all of these identifiers are 
# available it searches by all of them.
#
# Uses Google Books Data API, http://code.google.com/apis/books/docs/gdata/developers_guide_protocol.html
# 
# If a full view is available it returns a fulltext service response.
# If there is only a partial view or noview it presents an appropriate 
# highlighted_link. Unfortunately there is no way tell which of the noview 
# books provide a snippet view. GBS really needs a 4th 'preview' response
# 'snippet.' 
# 
# If a thumbnail_url is returned in the responses, a cover image is displayed.
# To get the size we want some manipulation of the thumbnail_url is 
# necessary. 

class GoogleBookSearch < Service
  # Identifiers used in API response to indicate viewability level
  ViewFullUri = 'http://schemas.google.com/books/2008#view_all_pages'
  ViewPartialUri = 'http://schemas.google.com/books/2008#view_partial'
  # None might also be 'snippet', but Google doesn't want to distinguish
  ViewNoneUri = 'http://schemas.google.com/books/2008#view_no_pages'
  ViewUnknownUri = 'http://schemas.google.com/books/2008#view_unknown'
  LinkPreviewUri = 'http://schemas.google.com/books/2008/preview'
  LinkInfoUri = 'http://schemas.google.com/books/2008/info'
  LinkThumbnailUri = 'http://schemas.google.com/books/2008/thumbnail'
  
  require 'open-uri'
  require 'zlib'
  require 'json'
  require 'hpricot'
  include MetadataHelper
  include UmlautHttp
  
  # required params
  
  # attr_reader is important for tests
  attr_reader :url, :display_name, :num_full_views 
  
  def service_types_generated
    types= [
      ServiceTypeValue[:fulltext], 
      ServiceTypeValue[:cover_image],
      ServiceTypeValue[:highlighted_link],
      ServiceTypeValue[:search_inside],
      ServiceTypeValue[:excerpts]]
    types.push(ServiceTypeValue[:referent_enhance]) if @referent_enhance
    return types
  end
  
  def initialize(config)
    # we include a callback in the url because it is expected that there will be one.
    @url = 'http://books.google.com/books/feeds/volumes?q='
    @display_name = 'Google Book Search'
    # number of full views to show
    @num_full_views = 1
    # default off for now
    @referent_enhance = false
    super(config)
  end
  
  def handle(request)
    # Google does a terrible job if we search on a serial, we might
    # get certain volumes back but there's no way to know they're just
    # certain volumes. And we can't be sure if this is a serial or not!
    # But if we think it's likely is a serial, bail out entirely. 
    return request.dispatched(self, true) if likely_serial?(request.referent)
    
    bibkeys = get_bibkeys(request.referent)
    return request.dispatched(self, true) if bibkeys.nil?
    data = do_query(bibkeys, request)

    enhance_referent(request, data) if @referent_enhance
    
    #return full views first
    full_views_shown = create_fulltext_service_response(request, data)

    # Add search_inside link if appropriate
    add_search_inside(request, data)
    
    # only if no full view is shown, add links for partial view or noview
    unless full_views_shown
      do_web_links(request, data)
    end
    
    thumbnail_url = find_thumbnail_url(data)
    if thumbnail_url
      add_cover_image(request, thumbnail_url)    
    end

    return request.dispatched(self, true)
  end

  # Take the FIRST hit from google, and use it's values to enhance
  # our metadata. Will NOT overwrite existing data. 
  def enhance_referent(request, data)
 
    entry = data.at('/*/entry')

    element_enhance(request, "title", entry.at("dc:title"))
    element_enhance(request, "au", entry.at("dc:creator"))
    element_enhance(request, "pub", entry.at("dc:publisher"))
    element_enhance(request, "date", entry.at("dc:date"))

    # While the GBS docs suggest we can get an OCLCnum or LCCN
    # here, in fact that seems not to be so. But we can get an ISBN,
    # useful if we looked up by LCCN or OCLCnum in GBS and don't have
    # one already.
    unless ( request.referent.isbn  )      
      # Usually provides an ISBN-10 and a -13. We don't care, either
      # is fine for us, just take the first one present.  
      if (  isbn_element = entry.search("dc:identifier").find {|el| el.inner_html =~ /^ISBN\:/} )

        # Just get the whole thing starting at position 5 please. 
        isbn = isbn_element.inner_html[5, 1000]
        
        request.referent.add_identifier( "urn:isbn:#{isbn}")
      end
    end
    
  end

  # Will not over-write existing referent values. 
  def element_enhance(request, rft_key, hpricot_el)
    if (hpricot_el)
      request.referent.enhance_referent(rft_key, hpricot_el.inner_html, true, false, :overwrite => false)
    end
  end

  # We can't be sure if it's a serial or not, but we take a guess
  # , cause we aren't going to bother searching google if it is.
  def likely_serial?(rft)
    # If genre=journal was really set and was accurate, it's a journal.
    # But often it's not. If we have an ISSN, that's likely enough to
    # be a journal. 
     (rft.metadata['genre'] == "journal") || (not get_issn(rft).nil?)
  end
  
  # returns nil or escaped string of bibkeys
  # to increase the chances of good hit, we send all available bibkeys 
  # and later dedupe by id.
  # FIXME Assumes we only have one of each kind of identifier.
  def get_bibkeys(rft)
    isbn = get_isbn(rft)
    oclcnum = get_oclcnum(rft)
    lccn = get_lccn(rft)

    # Google oddly seems to want prefix mashed right up
    # with identifier, eg http://books.google.com/books/feeds/volumes?q=OCLC32012617 
    # except for ISBN it lets us do a reasonable search
    keys = []
    keys << 'isbn:' + isbn if isbn
    keys << 'OCLC' + oclcnum if oclcnum
    
    # LCCN is especially unreliable in GBS,
    # only use it if we've got nothing else
    keys << 'LCCN' + lccn if lccn && keys.length == 0
    
    return nil if keys.empty?
    keys = CGI.escape( keys.join(' OR ') )
    return keys
  end
  
  def do_query(bibkeys, request)    
    headers = build_headers(request)
    link = @url + bibkeys

    
    response = open(link, 'rb', headers)
    xml = response.read

    
    #return REXML::Document.new(xml)
    return Hpricot.XML(xml)
    
        
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
    return {'X-Forwarded-For' =>  original_forwarded_for ?
        original_forwarded_for  :
        request.client_ip_addr.to_s}    
  end
  
  def find_entries(gbs_response, viewabilities)
    unless (viewabilities.kind_of?(Array))
      viewabilities = [viewabilities]
    end

    entries = gbs_response.search("/*/entry").find_all do |entry|
      viewability = entry.at("gbs:viewability")
      (viewability && viewabilities.include?(viewability["value"]))           
    end

    return entries
  end
  
  # HPricot element, and a value of the rel attribute on the <link> you are
  # interested in. 
  def extract_link(entry, rel_type)
    entry.at("link[@rel='#{rel_type}']")["href"]
  end
  
  # We only create a fulltext service response if we have a full view.
  # We create only as many full views as are specified in config.
  def create_fulltext_service_response(request, data)
    display_name = @display_name

    full_views = find_entries(data, ViewFullUri)
    
    return nil if full_views.empty?
    count = 0
    full_views.each do |fv|
      uri = extract_link(fv, LinkPreviewUri)
    
      #note = fv['bib_key'].gsub(':', ': ') #get_search_title(request.referent)
      request.add_service_response(
        {:service=>self, 
          :display_text=>display_name, 
          :url=>uri}, 
          #:notes=>note}, 
        [ :fulltext ]) 
      count += 1
      break if count == @num_full_views
    end   
    return true
  end

  def add_search_inside(request, data)
    # Just take the first one we find, if multiple
    searchable_view = find_entries(data, [ViewFullUri, ViewPartialUri])[0]        
    
    if ( searchable_view )
      url = extract_link(searchable_view, LinkInfoUri)
      
      request.add_service_response( 
        {:service => self,
        :display_text=>@display_name,
        :url=> url},
        [:search_inside]
       )                  
    end
    
  end
  
  # create highlighted_link service response for partial and noview
  # Only show one web link. prefer a partial view over a noview.
  # Some noviews have a snippet/search, but we have no way to tell. 
  def do_web_links(request, data)

    # some noview items will have a snippet view, but we have no way to tell
    info_views = find_entries(data, ViewPartialUri)
    viewability = ViewPartialUri
    
    if info_views.blank?
      info_views = find_entries(data, ViewNoneUri)
      viewability = ViewNoneUri  
    end
    
    # Shouldn't ever get to this point, but just in case
    return nil if info_views.blank?
    
    url = ''
    iv = info_views.first
    type = nil
    if (viewability == ViewPartialUri && 
        url = extract_link(iv, LinkPreviewUri))
      display_text = @display_name
      type = ServiceTypeValue[:excerpts]
    else
      url = extract_link(iv, LinkInfoUri)
      display_text = "Book Information"
      type = ServiceTypeValue[:highlighted_link]
    end
    request.add_service_response( { 
        :service=>self,    
        :url=>url,
        :display_text=>display_text},
          [type]    
       )
  end
  

  
 
  # Not all responses have a thumbnail_url. We look for them and return the 1st.
  def find_thumbnail_url(data)
    entries = data.search("/*/entry").collect do |entry|
      thumb_entry = entry.at("link[@rel='#{LinkThumbnailUri}']")
      thumb_entry ? thumb_entry['href'] : nil                 
    end
    
    # removenill values
    entries.compact!    
    
    # pick the first of the available thumbnails, or nil
    return entries[0]
  end
  

  def add_cover_image(request, url)
    # We do like in Amazon service and return three sizes of images. 
    # it seems only size 1 = large and 5 = small work so medium and large 
    # are the same
    [["small", '5'],["medium", '1'], ["large", '1']].each do | size, zoom_size |
      zoom_url = url.sub('zoom=5', "zoom=#{zoom_size}")
      
      # if we're sent to a page other than the frontcover then strip out the
      # page number and insert front cover
      zoom_url.sub!(/&pg=.*?&/, '&printsec=frontcover&')
      
      request.add_service_response({
          :service=>self, 
          :display_text => 'Cover Image',
          :key=> size, 
          :url => zoom_url, 
          :service_data => { :size => size }
        },
        [ServiceTypeValue[:cover_image]])
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
      url = base + "&q=#{query}#search"
      return url
    end
  end
  
end


# Test WorldCat links
# FIXME: This produces two 'noview' links because the ids don't match.
#   This might be as good as we can do though, unless we want to only ever show
#   one 'noview' link. Notice that the metadata does differ between the two.
# http://localhost:3000/resolve?url_ver=Z39.88-2004&rfr_id=info%3Asid%2Fworldcat.org%3Aworldcat&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook&req_dat=%3Csessionid%3E&rft_id=info%3Aoclcnum%2F34576818&rft_id=urn%3AISBN%3A9780195101386&rft_id=urn%3AISSN%3A&rft.aulast=Twain&rft.aufirst=Mark&rft.auinitm=&rft.btitle=The+prince+and+the+pauper&rft.atitle=&rft.date=1996&rft.tpages=&rft.isbn=9780195101386&rft.aucorp=&rft.place=New+York&rft.pub=Oxford+University+Press&rft.edition=&rft.series=&rft.genre=book&url_ver=Z39.88-2004
#
# Snippet view returns noview through the API
# http://localhost:3000/resolve?rft.isbn=0155374656
#
