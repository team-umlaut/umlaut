# Service to search Internet Archive (archive.org) via screen scraping

# Test links/searches:
# titles "Why were we created" and "Andrew Bird" have no author

class InternetArchiveScraper < Service
  require 'cgi'
  require 'hpricot'
  require 'open-uri'
  
  attr_reader :url
  
  def service_types_generated
    return [ ServiceTypeValue[:fulltext], ServiceTypeValue[:web_link] ]
  end
  
  def initialize(config)
    # Default base URL for archive.org search. Override in config param if
    # desired. 
    @url = 'http://www.archive.org/search.php?query='
    super(config)
  end
  
  def handle(request) 
    # first try a title or title-author search
    result = do_title_query(request)
    # fall back on an isbn search
    if result.nil?
      isbn = clean_isbn(request.referent.metadata['isbn'])
      # simple ISBN validation
      if isbn.length == 10 or isbn.length == 13
        result = do_isbn_query(request, isbn)
        # try the isbn with dashes
        if result.nil?
          do_isbn_query( request, dash_isbn(isbn) )
        end
      end
    end     
    return request.dispatched(self, true)
  end
  
  # remove dashes 
  def clean_isbn(isbn)
    isbn.gsub('-', '')
  end
  
  # insert dashes in a common way
  def dash_isbn(isbn)
    # handles both 10 and 13-digit ISBNs 
    if isbn.length == 10
      insertion_points = [1, 9, 11]
    elsif isbn.length == 13
      insertion_points = [3, 7, 13, 15]
    end
    insertion_points.each do |point|
      isbn = isbn.insert(point, '-')
    end
    isbn
  end
  
  def do_isbn_query(request, isbn)
    do_query(request, isbn)
  end
 
  def do_title_query(request)
    # before title query we try to get a title
    query = self.define_title_query(request.referent)
    return nil if query.nil?
    do_query(request, query)
  end
   
  # TODO strip off special characters like ?
  def define_title_query(rft)
    title, creator = get_search_terms(rft)
    return nil if title.nil?
    query =  "title:(#{title})"
    query << " AND creator:(#{creator})" if creator    
    query
  end
  
  def get_search_terms(rft)
    # Just make one call to create metadata hash
    metadata = rft.metadata
    title = nil
    if rft.format == 'journal' && metadata['atitle']
      title = metadata['atitle']
    elsif rft.format == 'book'
      title = metadata['btitle'] unless metadata['btitle'].blank?
      title = metadata['title'] if title.blank?
    end

    return nil if title.blank?

    # Identify dc.creator query. Prefer aulast alone if available.
    creator = nil
    creator = metadata['aulast'] unless metadata['aulast'].blank?
    creator = metadata['au'] if creator.blank?

    # For books, strip off subtitle after and including a ':'. 
    # Reduce false negatives by stripping it. 
    if (rft.format == 'book')
      colon_index = title.index(':')
      title = title.slice( (0..colon_index-1)  ) if colon_index
    end
    
    return title, creator
  end
   
   
  def do_query(request, query)
    # TODO make the type configurable
    types = ['texts', 'audio'] 
    # good_response flag determines if fallback searches should be done
    good_response = nil
    # searches each type separately returning any results
    types.each do |type|
      link = @url + CGI::escape("mediatype:#{type} AND #{query}")
      doc = Hpricot(open(link))    
      response = do_scrape(doc)
      next if response.empty? 
      good_response = true
      
      # TODO make the number of responses returned configurable
      first_response = response[0]
      url = "http://www.archive.org" + first_response[:url]
      display_name = @display_name || "Internet Archive (#{type})"
      note = first_response[:title] 
      note << " by " + first_response[:author] if first_response[:author]    
      request.add_service_response({:service=>self, :display_text=>display_name, :url=>url, :notes=>note}, [:fulltext])
    end
    good_response
  end
  
  # orchestrates the scraping after do_query has gotten the page
  def do_scrape(doc)
    results = doc.search("//td[@class='hitCell']")
    array = []
    results.each do |result|
      hash = {}
      hash[:url] = (result/"a[@class='titleLink']").first[:href]
      # FIXME is it necessary to remove spans here?
      hash[:title] = remove_highlighting_spans( (result/"a[@class='titleLink']").inner_html )
      author = scrape_author(result) 
      hash[:author] = remove_highlighting_spans(author) unless author.nil?
      array << hash          
    end
    array
  end
  
  # scraping the author from the page
  def scrape_author(result)
    # strip the spans out so that we can get the first text node
    # TODO haven't spans already been removed?
    within_cell = remove_highlighting_spans(result.inner_html)
    new_doc = Hpricot(within_cell)
    text_arr = new_doc.children.select{|e| e.text?} 
    #take the first one and then strip off a leading dash
    possible_author = text_arr[0].to_s    
    if possible_author =~ /^ - /  
      possible_author.lstrip.sub(/^- /, '')
    else
      return nil
    end   
  end
  
  # IA highlights search terms with spans. To ease scraping we remove them.
  # What helps users of the website makes the screen scraper jump through more hoops.
  def remove_highlighting_spans(text)
     text.gsub!('<span class="searchTerm">','')
    text.gsub('</span>','')
  end
   
end
