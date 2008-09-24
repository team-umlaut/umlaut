# Needs to be called Hip3Service to avoid conflicting with Hip3 module
# Params include:
# map_856_to_service :  Umlaut ServiceTypeValue to map 856 links to. Defaults
#                     to fulltext_title_level
# suppress_urls:      array of strings or regexps to NOT use from the catalog.
#                     Used for urls that duplicate SFX targets but which aren't
#                     caught by SfxUrl.sfx_controls_url. Regexps can be put
#                     in the services.yml like this:    
#                        !ruby/regexp '/sagepub.com$/'

class Hip3Service < Service
  required_config_params :base_path, :display_name
  attr_reader :base_path

  def initialize(config)
    # defaults
    @map_856_to_service = 'fulltext_title_level'
    @suppress_urls = []
    super(config)

    # Trim question-mark from base_url, if given
    @base_path.chop! if (@base_path.rindex('?') ==  @base_path.length)     
  end

  # Standard method, used by background service updater. See Service docs. 
  def service_types_generated
    # We generate full text and holdings types, right now.
    types = [ ServiceTypeValue[:fulltext], ServiceTypeValue[:holding], ServiceTypeValue[:table_of_contents] ]
    
    return types
  end
  
  def handle(request)
    
    bib_searcher = Hip3::BibSearcher.new(@base_path)
    
    issn = request.referent.metadata['issn']
    isbn = request.referent.metadata['isbn']
    # don't send mal-formed issn
    bib_searcher.issn = issn if issn =~ /\d{4}(-)?\d{3}(\d|X)/ 
    bib_searcher.isbn = isbn 

    
    bib_array = bib_searcher.search
    # Let's find any URLs, and add full text responses for those.
    urls = bib_array.collect {|b| b.marc_xml.find_all {|f| '856' === f.tag}}.flatten
    urls_seen = Array.new # for de-duplicating urls from catalog.
    urls.each do |field|
      url = field['u']

      next if urls_seen.include?(url)
      # Don't add the URL if it matches our SFXUrl finder, because
      # that means we think this is an SFX controlled URL.
      next if SfxUrl.sfx_controls_url?(url)
      # We have our own list of URLs to suppress, array of strings
      # or regexps.
      next if @suppress_urls.find {|suppress| suppress === url}
      
      # No u field? Forget it.
      next if url.nil?
      
      urls_seen.push(url)
      
      # 	puts field.subfields.collect {|f| f.value if f.code == 'z'}.join
      # For the text to display, let's try taking just the domain from the
      # url
      display_name = nil

      begin
        u_obj = URI::parse( url )
        display_name = u_obj.host
      rescue Exception
          #
      end
      # Okay, whole url then. 
      display_name = url if display_name.nil?
      value_text = Hash.new
      # get all those $z subfields and put em in notes.      
      value_text[:url] = url

      # subfield 3 is being used for OCA records loaded in our catalog.
      value_text[:notes] =
      field.subfields.collect {|f| f.value if (f.code == 'z' || f.code == '3') }.compact.join('; ')

      unless ( field['3']) # subfield 3 is in fact some kind of coverage note, usually. 
        value_text[:notes] += "; " unless value_text[:notes].blank? 
        value_text[:notes] += "Dates of coverage unknown."
      end

      # Do we think this is a ToC link?
      service_type_value = self.url_service_type( field ) 
      
      # Add the response
      request.add_service_response({:service=>self, :display_text=>display_name, :url=>url, :notes=>value_text[:notes], :service_data=>value_text}, [service_type_value])
    end
    
    #Okay, we actually want to make each _copy_ into a service response.
    #A bib may have multiple copies. We are merging bibs, and just worrying
    #about the aggregated list of copies.
    holdings = bib_array.collect { |bib| bib.holdings }.flatten
    holdings.each do |holding|

    
      next if holding.dummy?

      url = holding.bib.http_url
      
      service_data = {}
      service_data[:source_name] = holding.collection_str unless holding.collection_str.nil?
      service_data[:call_number] = holding.call_no
      service_data[:status] = holding.status_str
      service_data[:location] = holding.location_str
      service_data[:collection_str] = holding.collection_str
      service_data[:copy_str] = holding.copy_str
      service_data[:coverage_str] = holding.coverage_str
      service_data[:coverage_str_array] = holding.coverage_str_to_a 
      service_data[:notes] = holding.notes
      service_data[:url] = url
      # If it's not a serial copy, we can add a direct request url.
      unless ( holding.kind_of?(Hip3::SerialCopy))
        service_data[:request_url] = self.base_path + "?profile=general&menu=request&aspect=none&bibkey=#{holding.bib.bibNum}&itemkey=#{holding.id}"


      end
      
      display_text = ""
      #display_text << (holding.location_str + ' ')unless holding.location_str.nil?
      display_text << (holding.copy_str + ' ') unless holding.copy_str.nil?

      # coverage strings, may be multiple
      holding.coverage_str_to_a.each {|s| display_text << (s + ' ')}

      display_text << holding.notes unless holding.notes.nil?
      service_data[:display_text] = display_text
      
      request.add_service_response( {:service=>self, :display_text => display_text, :notes=>service_data[:notes], :url=> url, :service_data=>service_data }, ['holding']  )

    end
    return request.dispatched(self, true)
  end

    def url_service_type( field )
      # LC records here at hopkins have "Table of contents only" in the 856$3
      # Think that's a convention from LC? 
      if (field['3'] && field['3'].downcase == "table of contents only")
        return "table_of_contents"
      elsif (field['3'] && field['3'].downcase =~ /description/)
        return "abstract"
      else
        return @map_856_to_service
      end      
    end

end
