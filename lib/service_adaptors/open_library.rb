# Searches Open Library for fulltext
# 
# 
#

class OpenLibrary < Service
  require 'open-uri'
  require 'json'
  include MetadataHelper
  
  attr_reader :url
  
  def service_types_generated
    return [
      ServiceTypeValue[:fulltext],
      ServiceTypeValue[:highlighted_link],
      ServiceTypeValue[:cover_image]
      # FIXME add these service types
      #ServiceTypeValue[:table_of_contents]
      #ServiceTypeValue[:search_inside]
    ]
  end
  
  def initialize(config)
    @api_url = "http://openlibrary.org/api"
    @display_name = "Open Library"
    # in case the structure of an empty response changes 
    @empty_response = {"result" => [], "status" => "ok"}
    # FIXME change this to 1
    @num_full_views = 3
    
    # openlibrary goes straight to the flipbook; archive.org to main page
    @fulltext_base_url = 'http://archive.org/details' #'http://openlibrary.org/details'
    @download_link = true
    super(config)
  end
  
  def handle(request)
    find_fulltext(request)    
    return request.dispatched(self,true)
  end
  
  def find_fulltext(request)
    ids = get_identifiers(request.referent)
    return nil if ids.blank?
    ol_keys = do_id_query(ids)    
    return nil if ol_keys.blank?
    
    editions = get_editions(ol_keys)
    return nil if editions.blank?
    
    full_text_editions = select_fulltext(editions)
    add_cover_image(request, editions)
    unless full_text_editions.blank?
      create_fulltext_service_responses(request, full_text_editions)
      create_download_link(request, full_text_editions) if @download_link
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
      ed.has_key?('ocaid')
    end
  end
  
  def create_fulltext_service_responses(request, editions)
    count = 0
    #note = @note
    editions.each do |ed|
      title = ed['title']
      url = @fulltext_base_url + '/' +ed['ocaid']
      request.add_service_response(
        {:service=>self, 
          :display_text=>@display_name, 
          :url=>url, 
          :notes=>title}, 
        [ :fulltext ]) 
      
      count += 1
      break if count == @num_full_views
    end  
  end
  
  def create_download_link(request, editions)
    return nil unless editions
    # FIXME precheck the size!
    ed = editions[0]
    return nil unless ed['ocaid']
    server = "www.archive.org"
    pdf = "/download/"<< ed['ocaid'] << "/" << 
      ed['ocaid'] << ".pdf"
    url = "http://" << server << pdf
    note = determine_download_size(server, pdf)
    request.add_service_response(
        {:service=>self, 
          :display_text=>"Download: " << ed['title'], 
          :url=>url, 
          :notes=> ("%.1f" %  note) + " MB"
        }, 
        [ :highlighted_link ]) 
  end
  
  # they redirect so we actually have to do two HEAD requests to get the
  # actual content length
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
      bytes = resp['Content-Length'].to_i 
      return bytes_to_mb(bytes)
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
    request.add_service_response({
          :service=>self, 
          :display_text => 'Cover Image',
          :key=> 'medium', 
          :url => url, 
          # FIXME how is service_data used? we just put in fake data for asin
          # and repeated the size from key
          :service_data => {:asin => 'asin', :size => 'medium' }
        },
        [ServiceTypeValue[:cover_image]])
  end
  
  # pick the first of the coverimages found
  def find_coverimages(editions)
    editions.map{|ed| ed['coverimage']}.compact[0]
  end
  
end