# Searches OpenContent indexes via SRU. 
# See http://indexdata.dk/opencontent/
#
# Creates fulltext type responses, and maybe sometimes web_link.
#
# No config params needed, although you can supply url if you somehow have
# another sru provider that has exactly the same indexes as OpenContent. 
class OpencontentSearch < Service
  require 'hpricot'
  require 'sru'
  attr_reader :url

  @@db_display_name = {"oaister" => "OAIster", "gutenberg" => "Project Gutenberg", "oca-all" => "Open Content Alliance"}
  
  def service_types_generated
    return [ ServiceTypeValue[:fulltext], ServiceTypeValue[:web_link] ]
  end

  def initialize(config)
    # Default base URL for openContent SRU search. Override in config param if
    # desired. 
    @url = 'http://opencontent.indexdata.com/'
    super(config)
  end
  
  def handle(request)
    databases = identify_databases(request)
    query = self.define_query(request.referent)

    # No dbs identified? No query to be done? Nevermind then.  
    return request.dispatched(self, true) if databases.blank? || query.blank?
      
    do_query(request, databases, query)

    return request.dispatched(self, true)
  end

  # Which openContent databases (collections) are appropriate for
  # given citation?
  def identify_databases(request)
    if (request.referent.format == "journal" && ! request.referent.metadata['atitle'].blank? )
      databases = ["oaister"]
    elsif request.referent.metadata['genre'] == 'proceeding'
      databases = ["oaister", "oca-all"]
    elsif request.referent.format == "book"
      databases = ["oca-all", "gutenberg"]    
    end
    return databases
  end

  # Returns an SRU query, or nil if no applicable query can be created. 
  def define_query(rft)
    # All databases will take a dc.title, but that's the only common
    # denominator. We make a query that will work in any openContent db. 
    
    metadata = rft.metadata    
    
    # Identify dc.title query
    title = nil
    if rft.format == 'journal' && metadata['atitle']
      title = metadata['atitle']
    elsif rft.format == 'book'
      title = metadata['btitle'] unless metadata['bititle'].blank?
      title = metadata['title'] if title.blank?
    end

    return nil if title.blank?

    # Identify dc.creator query. Prefer aulast alone if available.
    creator = nil
    creator = metadata['aulast'] unless metadata['aulast'].blank?
    creator = metadata['au'] if creator.blank?


    # For books, strip off subtitle after and including a ':'. Subtitle
    # is sometimes indexed, sometimes not, sometimes with colon, sometimes
    # not. Reduce false negatives by stripping it. 
    if (rft.format == 'book')
      colon_index = title.index(':')
      title = title.slice( (0..colon_index-1)  ) if colon_index
    end
    
    # Some random weird normalizing discovered by example of what works
    # with OAISter.
    # In general, changing punctuation to spaces seems helpful for eliminating
    # false negatives. Not only "weird" punctuation like curly-quotes seems
    # to result in false negative, but even normal punctuation can. If it's
    # not a letter or number, let's get rid of it. This method may or may
    # not be entirely unicode safe, but initial experiments were satisfactory.
    # \342\200\231 is curly apostrophe
    #title.gsub!(/[^a-zA-Z0-9]/, " ")
    title = title.chars.gsub(/[^\w\s]/, ' ').to_s

    
    # Create the SRU query
    query = 'dc.title = "'+title+'" '
    
    unless creator.blank?
      query += " and cql.serverChoice=\"#{creator}\"" 
    end

    return query    
  end
  
  def do_query(request, dbs, query)
    dbs.each do |db|
      client = SRU::Client.new(self.url+db)
      results = client.search_retrieve(query, :maximumRecords=>10)

      results.each do |raw_dc_xml|
        # Get <dc:identifier> out, that's the URL.
        xml = Hpricot.XML( raw_dc_xml.to_s )

        url, display_name, note = extract_data(db, xml, results.number_of_records)
        
        request.add_service_response({:service=>self, :display_text=>display_name, :url=>url, :notes=>note}, [:fulltext])        
      end
    end
  end

  # Give an OpenContent db, and OpenContent XML response in Hpricot. Plus
  # the number of hits from this db. (A disambiguating note will be provided
  # if neccesary). 
  # returns url, display_name, and note
  def extract_data(db, xml, num_hits)
    url = nil
    display_name = nil
    notes = []
    
    dc_id = xml.at('dc:identifier')
    url = dc_id.inner_html if dc_id

    if num_hits > 1
      # Add some disambiguating metadata. We don't have much to offer.
      title = xml.at('dc:title').inner_html
      creator = xml.at('dc:creator').inner_html
      notes << "#{title} / #{creator}"
    end
    
    if db == "oaister"
      # Return actual URL as name, with via OAISter as note. 
      begin
        u_obj = URI::parse( url )
        display_name = u_obj.host
      rescue
        # Okay then, forget trying to get the host out. 
        display_name = url
      end
      notes << "Via #{@@db_display_name[db]}"
    else
      # Return name of source as name, no note.
      display_name = (@@db_display_name[db] || "OpenContent Search")
    end

    return url, display_name, notes.join('. ')   
  end
end