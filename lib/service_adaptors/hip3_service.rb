# Needs to be called Hip3Service to avoid conflicting with Hip3 module
# Params include:
# map_856_to_service :  Umlaut ServiceTypeValue to map 856 links to. Defaults
#                     to fulltext_title_level
class Hip3Service < Service
  required_config_params :base_path, :display_name
  attr_reader :base_path

  def initialize(config)
    super(config)
    # Trim question-mark from base_url, if given
    @base_path.chop! if (@base_path.rindex('?') ==  @base_path.length)
    @map_856_to_service = 'fulltext_title_level' unless @map_856_to_service
  end

  # Standard method, used by background service updater. See Service docs. 
  def service_types_generated
    # We generate full text and holdings types, right now.
    return [ ServiceTypeValue[:fulltext], ServiceTypeValue[:holding] ]
  end
  
  def handle(request)
    bib_searcher = Hip3::BibSearcher.new(@base_path)

    
    bib_searcher.issn = request.referent.metadata['issn']
    bib_searcher.isbn = request.referent.metadata['isbn']
    
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
      value_text[:notes] = 
      field.subfields.collect {|f| f.value if f.code == 'z'}.compact!.join(' ')
      # Add the response
      request.add_service_response({:service=>self, :display_text=>display_name, :url=>url, :notes=>value_text[:notes], :service_data=>value_text}, [@map_856_to_service])
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

  #def to_holding(service_response)
    # The hash we put in value_text is suitable to return to the view already
  #  return YAML.load(service_response.value_text)
  #end

  # Copied from sfx.rb. Repeating ourselves, sorry. 
  #def to_fulltext(response)
    
  
  #  value_text = YAML.load(response.value_text)
  #  return {:display_text=>response.response_key, :notes=>value_text[:notes],:coverage=>value_text[:coverage],:source=>value_text[:source]}
  #end
  
  #def response_url(service_response)
  #  debugger
  #  1+1
    # We stuck the URL for the relevant bib in the value_string
   #return service_response.value_string
  # return service_response[:url]
  #end


  
end
