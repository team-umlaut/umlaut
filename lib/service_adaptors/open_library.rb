# EXPERIMENTAL, uncomplete. 
# Searches Open Library for fulltext, and cover images.
# To some extent duplicates what the InternetArchive service does,
# but using the OpenLibrary API.
#
# This service right now will only search on isbn/oclcnum/lccn identifiers,
# not on title/author keyword.
#
# Only a subset of OL cover images are actually available via API (those
# submitted by users). Here is an example: ?rft.isbn=0921307802
# Size of images returned is unpredictable. They can be huge sometimes.
# Counting on enforced re-sizing in img tag attributes. 
# 
#

class OpenLibrary < Service
  require 'open-uri'
  require 'json'
  include MetadataHelper
  
  attr_reader :url
  
  def service_types_generated
    
    types = Array.new
    types.push( ServiceTypeValue[:fulltext]) if @get_fulltext
    types.push( ServiceTypeValue[:highlighted_link]) if @get_fulltext
    types.push( ServiceTypeValue[:cover_image]) if @get_covers 

    return types
    
    # FIXME add these service types
    #ServiceTypeValue[:table_of_contents]
    #ServiceTypeValue[:search_inside]
  
  end
  
  def initialize(config)
    @api_url = "http://openlibrary.org/api"
    @display_name = "Open Library"
    # in case the structure of an empty response changes 
    @empty_response = {"result" => [], "status" => "ok"}
    @num_full_views = 1

    # Can turn on and off each type of service
    @get_fulltext = true
    @get_covers = true
    @enhance_metadata = true
    
    # openlibrary goes straight to the flipbook; archive.org to main page
    @fulltext_base_url = 'http://archive.org/details' #'http://openlibrary.org/details'
    @download_link = true
    super(config)
  end
  
  def handle(request)
    get_data(request)    
    return request.dispatched(self,true)
  end
  
  def get_data(request)
    ids = get_identifiers(request.referent)
    return nil if ids.blank?
    ol_keys = do_id_query(ids)    
    return nil if ol_keys.blank?
    
    editions = get_editions(ol_keys)
    return nil if editions.blank?

    enhance_metadata(request.referent, editions) if @enhance_metadata
    
    add_cover_image(request, editions) if @get_cover_image

    if ( @get_fulltext)
      full_text_editions = select_fulltext(editions)
      unless full_text_editions.blank?
        create_fulltext_service_responses(request, full_text_editions)
        create_download_link(request, full_text_editions) if @download_link
      end
    end
    
    # Open Libary metadata looks messy right now and incomplete
    # if there is only one edition returned then we return a highlighted link
    # otherwise best to just leave it off
    if editions.length == 1
      # FIXME add this method
      #create_highlighted_link(request, editions)
    end
  
  end
  
  def get_identifiers(rft)
    isbn = get_identifier(:urn, "isbn", rft)
    oclcnum = get_identifier(:info, "oclcnum", rft)
    lccn = get_identifier(:info, "lccn", rft)
    
    h = {}
    h['isbn'] = isbn unless isbn.blank?
    h['oclcnum'] = oclcnum unless oclcnum.blank?
    h['lccn'] = lccn unless lccn.blank?
    return h
  end
  
  # only returns the unique keys from all the results
  def do_id_query(ids)
    responses = []
    ids.each do |k, v|
      new_key_value = map_key(k, v)
      next if new_key_value.blank? #we probably have bad ISBN, could be bad key though
      responses <<  get_thing(new_key_value)
    end
    selected = responses.map { |r| r['result'] }.flatten.compact.uniq
    return selected
  end
  
  # given a hash as a query it returns a hash
  def get_thing(query_hash)
    query = {"type" => "/type/edition"}.merge(query_hash)
    response = open(@api_url + "/things?query=" + CGI.escape(query.to_json) ).read
    JSON.parse(response)
  end

  # Contacts OL and gets data records for editions/manifestations
  # matching any of keys we have.  
  def get_editions(ol_keys)
    editions = []
    ol_keys.each do |k|
      link = @api_url + "/get?key=" + k
      resp = open(link).read
      editions << JSON.parse(resp)['result']
    end
    return editions
  end
  
  def map_key(k, v)
    new_key = case k
    when "lccn" then "lccn"
    when "oclcnum" then "oclc_numbers"
    when "isbn"
      if v.length == 10
        "isbn_10"
      elsif v.length == 13
        "isbn_13"
      end
    end
    return { new_key => v}
  end
  
  # right now we only know of a work having fulltext if it has an ocaid
  # in case we discover other ways to determine fulltext availability we                                     
  # move it to its own method
  def select_fulltext(editions)
    editions.select do |ed|
      ! ed['ocaid'].blank?
    end
  end
  
  def create_fulltext_service_responses(request, editions)
    count = 0
    #note = @note
    editions.each do |ed|
      title = ed['title']
      url = @fulltext_base_url + '/' +ed['ocaid']
      request.add_service_response(
          :service=>self, 
          :display_text=>@display_name, 
          :url=>url, 
          :notes=>title, 
          :service_type_value =>  :fulltext ) 
      
      count += 1
      break if count == @num_full_views
    end  
  end

  # TODO: If first one doesn't have a download, try second?
  # In general, we need a better way of grouping ALL the results
  # available for the user. 
  # Creates a highlighted_link for download of PDF
  # for first edition listed. 
  def create_download_link(request, editions)
    return nil unless editions
    ed = editions[0] if editions.length
    return nil unless ed['ocaid']
    server = "www.archive.org"
    pdf = "/download/"<< ed['ocaid'] << "/" << 
      ed['ocaid'] << ".pdf"
    url = "http://" << server << pdf
    
    bytes = determine_download_size(server, pdf)
    return nil if bytes.nil? || bytes == 0
    
    note = bytes_to_mb(bytes)

    
    request.add_service_response(
          :service=>self, 
          :display_text=>"Download: " << ed['title'], 
          :url=>url, 
          :notes=> ("%.1f" %  note) + " MB",
          :service_type_value => :highlighted_link ) 
  end
  
  # they redirect so we actually have to do two HEAD requests to get the
  # actual content length. Returns bytes as int. 
  def determine_download_size(server, pdf)
    real_location = ''
    Net::HTTP.start(server, 80) do |http|
      # Send a HEAD request
      response = http.head(pdf)      
      # Get the real location
      real_location = response['Location']
    end    
    m = real_location.match(/http:\/\/(.*?)(\/.*)/)
    real_server = m[1]
    real_pdf = m[2]
    Net::HTTP.start(real_server, 80) do |http|
      # Send a HEAD request
      resp = http.head(real_pdf)

      return nil if resp.kind_of?(Net::HTTPServerError) || resp.kind_of?(Net::HTTPClientError) 
      
      bytes = resp['Content-Length'].to_i
      return bytes
    end
  end
  
  def bytes_to_mb(bytes)
    bytes / (1024.0 * 1024.0)
  end
  
  def add_cover_image(request, editions)
    cover_image = find_coverimages(editions)
    return nil if cover_image.blank?
    #FIXME need to add other sizes
    #FIXME correct @urls and use one of those
    url = "http://openlibrary.org" + cover_image
    request.add_service_response(
          :service=>self, 
          :display_text => 'Cover Image',
          :key=> 'medium', 
          :url => url, 
          :size => 'medium',
          :service_type_value => :cover_image)
  end
  
  # pick the first of the coverimages found
  def find_coverimages(editions)
    images = editions.map{|ed| ed['coverimage']}.compact
    # filter out fake ones
    images.reject! { |url| url =~ /book\.trans\.gif$/ }
    return images[0]
  end

  def enhance_metadata(referent, editions)
    # Which one should we use to enhance? Whichever has the largest
    # oclcnum, or if none of them have an oclcnum, then whichever
    # has the most metadata elements. 
    winner = nil
    winner_oclcnum = 0
    winner_numfields = 0
    editions.each do |e|
      score = score_metadata(e)
      if ( ( score[:oclcnum] && score[:oclcnum] > winner_oclcnum ) ||
           ( winner_oclcnum == 0 && score[:numfields] > winner_numfields)) 
           winner = e
           winner_oclcnum = score[:oclcnum] if score[:oclcnum]
           winner_numfields = score[:numfields]
      end
    end

    if (winner)
      referent.enhance_referent("title", winner["title"], true, false, {:overwrite=>false}) unless winner["title"].blank?
      
      referent.enhance_referent("pub", winner["publishers"].join(","), true, false, {:overwrite=>false}) unless winner["publishers"].blank?
      
      referent.enhance_referent("date", winner["publish_date"], true, false, {:overwrite=>false}) if winner["publish_date"] =~ /^\d\d\d\d$/
      
      referent.enhance_referent("pub", winner["publish_places"].join(","), true, false, {:overwrite=>false}) unless winner["publish_places"].blank?
      
      referent.enhance_referent("lccn", winner["lccn"][0], true, false, {:overwrite=>false}) unless winner["lccn"].blank?

      # ISBN, prefer 13 if possible
      referent.enhance_referent("isbn", winner["isbn_13"][0], true, false, {:overwrite=>false}) unless winner["isbn_13"].blank?
      
      referent.enhance_referent("isbn", winner["isbn_10"][0], true, false, {:overwrite=>false}) if winner["isbn_13"].blank? && ! winner["isbn_10"].blank?

      referent.enhance_referent("oclcnum", winner["oclc_numbers"][0], true, false, {:overwrite=>false}) unless winner["oclc_numbers"].blank?
      
    end    
      
  end

  # Score an edition in terms of how good it's metadata is.
  # Returns a two-element array, first element is OCLCnum (or nil),
  # second element is number of complete metadata elements.
  # We like an OCLCnum, especially a higher one, and we like more
  # elements. 
  def score_metadata(edition)
    oclcnum = edition["oclc_numbers"].collect {|i| i.to_i}.max unless edition["oclc_numbers"].blank?
    oclcnum = nil if oclcnum == 0

    score = 0
    ["title", "publish_places", "publishers", "publish_date", "isbn_10", "isbn_13", "lccn"].each do |key|
      score = score + 1 unless edition[key].blank?
    end

    return {:oclcnum => oclcnum, :numfields => score}
  end
  
end
