

class HipHoldingSearch < Service
  required_config_params :base_path, :display_name
  attr_reader :base_path

  def initialize(config)
    # Default preemption by any holding
    @preempted_by = { "existing_type" => "holding"}
    super(config)
    # Trim question-mark from base_url, if given
    @base_path.chop! if (@base_path.rindex('?') ==  @base_path.length)    
  end

  def service_types_generated
    return [ServiceTypeValue['holding_search']]    
  end

  def handle(request)  
    # Only do anything if we have no holdings results from someone else.
    holdings = request.service_types.find(:all, :conditions=>["service_type_value_id = ?", "holding"])
    
    if (holdings.length > 0)
      return request.dispatched(self, true)
    end

    ref_metadata = request.referent.metadata
    
    bib_searcher = Hip3::BibSearcher.new(@base_path)

    search_hash = {}
    
    hip_title_index = Hip3::BibSearcher::TITLE_KW_INDEX
    
    title = ref_metadata['jtitle']
    hip_title_index = Hip3::BibSearcher::SERIAL_TITLE_KW_INDEX if title # use journal title index for jtitle
    title = ref_metadata['btitle'] if title.blank?
    title = ref_metadata['title'] if title.blank?
    
    # No title? We can do nothing at present.
    if ( title.blank? ) ; return request.dispatched(self, true) ; end;
    
    # remove non-alphanumeric
    title.gsub!(/[^\w\s]/, ' ')
    # remove some obvious stop words, cause HIP is going to choke on em
    title.gsub!(/\bthe\b|\band\b|\bor\b|\bof\b|\ba\b/i,'')

    title_kws = title.split
    # limit to 12 keywords
    title_kws = title_kws.slice( (0..11) ) if title_kws.length > 12
    
    search_hash[hip_title_index] = title_kws
    
    # If it's a non-journal thing, add the author if we have an aulast (preferred) or au. 
    # But wait--if it's a book _part_, don't include the author name, since
    # it _might_ just be the author of the part, not of the book. 
    unless (request.referent.format == "journal" ||
              ( request.referent.format == "book" &&  ! ref_metadata['atitle'].blank?))
      # prefer aulast
      if ref_metadata['aulast']
        search_hash[ Hip3::BibSearcher::AUTHOR_KW_INDEX ] = [ref_metadata['aulast']]
      elsif ref_metadata['au']
        search_hash[ Hip3::BibSearcher::AUTHOR_KW_INDEX ] = [ref_metadata['au']]
      end
      
    end
    
    
    bib_searcher.search_hash = search_hash 
    unless bib_searcher.insufficient_query
          
      count = bib_searcher.count
      if (count > 0)
        service_data = {}
        service_data[:source_name] = @display_name
        service_data[:count] = count
        service_data[:display_text] = "#{count} possible #{case; when count > 1 ; 'matches' ; else; 'match' ; end} in #{display_name}"

        service_data[:url] = bib_searcher.search_url

        request.add_service_response({:service=>self, :display_text => service_data[:display_text], :url => service_data[:url], :service_data => service_data}, [ServiceTypeValue[:holding_search]])
      end      
    end
    return request.dispatched(self, true)
  end


  
end
