# Needs to be called Hip3Service to avoid conflicting with Hip3 module
# Params include:
# map_856_to_service :  Umlaut ServiceTypeValue to map 856 links to. Defaults
#                     to fulltext_title_level


class Hip3Service < Service
  required_config_params :base_path, :display_name
  attr_reader :base_path

  include MetadataHelper
  include MarcHelper

  def initialize(config)
    # defaults
    @map_856_to_service = 'fulltext'
    # If you are sending an OpenURL from a library service, you may
    # have the HIP bibnum, and include it in the OpenURL as, eg.
    # rft_id=http://catalog.library.jhu.edu/bib/343434 (except URL-encoded)
    # Then you'd set rft_id_bibnum_prefix to http://catalog.library.jhu.edu/bib/
    @rft_id_bibnum_prefix = nil
    @profile = "general"
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
    
    bib_searcher.issn = request.referent.issn 
    bib_searcher.isbn = request.referent.isbn
    bib_searcher.sudoc = get_sudoc(request.referent)

    results = bib_searcher.search

    add_856_links(request, results.collect {|b| b.marc_xml})
    add_copies(request, results)

    return request.dispatched(self, true)

  end

  # Takes an array of Hip3::Bib objects believed to be exact matches
  # for the citation querried, and adds response objects for them
  # Returns a hash of arrays of ServiceResponses added. 
  def add_copies(request, bib_array, options = {})
    #debugger
    
    # default    
    options[:match_reliability] ||= ServiceResponse::MatchExact

    responses_added = Hash.new

    

    
    #Okay, we actually want to make each _copy_ into a service response.
    #A bib may have multiple copies. We are merging bibs, and just worrying
    #about the aggregated list of copies.
    holdings = bib_array.collect { |bib| bib.holdings }.flatten
    bib_array.each do |bib|
      
    
      bib.holdings.each do |holding|
  
      
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
        unless ( holding.kind_of?(Hip3::SerialCopy) )
          service_data[:request_url] = self.base_path + "?profile=#{@profile}&menu=request&aspect=none&bibkey=#{holding.bib.bibNum}&itemkey=#{holding.id}"
        end
  
        # Need to say it's not an exact match neccesarily?
        
        unless ( options[:match_reliability] == ServiceResponse::MatchExact )
            service_data[:match_reliability] = options[:match_reliability]
            
            service_data[:edition_str] = edition_statement(bib.marc_xml)
        end
        
        display_text = ""
        #display_text << (holding.location_str + ' ')unless holding.location_str.nil?
        display_text << (holding.copy_str + ' ') unless holding.copy_str.nil?
  
        # coverage strings, may be multiple
        holding.coverage_str_to_a.each {|s| display_text << (s + ' ')}
  
        display_text << holding.notes unless holding.notes.nil?
        service_data[:display_text] = display_text
        
        response = request.add_service_response( {:service=>self, :display_text => display_text, :notes=>service_data[:notes], :url=> url, :service_data=>service_data }, ['holding']  )
  
        responses_added['holding'] ||= Array.new
        responses_added['holding'].push( response )
  
      end
    end

    return responses_added
  end

  def url_service_type( field )
    return service_type_for_856(field, :default_service_type =>  @map_856_to_service)            
  end

  def get_bibnum(rft)
    return nil unless @rft_id_bibnum_prefix

    identifier = rft.identifiers.find do |id| 
      id[0, @rft_id_bibnum_prefix.length] == @rft_id_bibnum_prefix
    end

    if ( identifier )
      return identifier[@rft_id_bibnum_prefix.length, identifier.length]
    else
      return nil
    end
    
  end

end
