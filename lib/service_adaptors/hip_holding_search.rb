

class HipHoldingSearch < Service
  required_config_params :base_path, :display_name
  attr_reader :base_path

  def initialize(config)
    super(config)
    # Trim question-mark from base_url, if given
    @base_path.chop! if (@base_path.rindex('?') ==  @base_path.length)      
  end

  def service_types_generated
    return [ServiceTypeValue['holding_search']]    
  end

  def handle(request)
    # Only do anything if we have no holdings results from someone else.
    holdings = request.service_types.find(:all, :conditions=>["service_type_value_id = ?", "holding_search"])
    
    if (holdings.length > 0)
      return request.dispatched(self, true)
    end
    
    bib_searcher = Hip3::BibSearcher.new(@base_path)

    hip_index = :title
    
    title = request.referent.metadata['jtitle']
    hip_index = :serial_title if title # use journal title index for jtitle
    title = request.referent.metadata['btitle'] if title.blank?
    title = request.referent.metadata['title'] if title.blank?
    
    # No title? We can do nothing at present.
    if ( title.blank? ) ; return request.dispatched(self, true) ; end;
    
    # remove non-alphanumeric
    title.gsub!(/[^A-z0-9\s]/, '')
    # remove some obvious stop words, cause HIP is going to choke on em
    title.gsub!(/\bthe\b|\band\b|\bor\b/i,'')

    
    
    bib_searcher.set_keywords(title.split , :index => hip_index  )
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
