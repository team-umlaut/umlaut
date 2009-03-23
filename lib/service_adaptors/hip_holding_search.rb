

class HipHoldingSearch < Hip3Service
  required_config_params :base_path, :display_name
  attr_reader :base_path

  def initialize(config)
    # Default preemption by any holding
    @preempted_by = { "existing_type" => "holding" }
    @keyword_exact_match = true
    super(config)
    # Trim question-mark from base_url, if given
    @base_path.chop! if (@base_path.rindex('?') ==  @base_path.length)    
  end

  def service_types_generated
    # Add one more to whatever the Hip3Service does. 
    return super.push(ServiceTypeValue['holding_search'])    
  end

  def normalize_title(arg_title, options = {})
    return nil if arg_title.nil?
    title = arg_title.clone
    
    return nil if title.blank?

    # Sometimes titles given in the OpenURL have some additional stuff
    # in parens at the end, that messes up the search and isn't really
    # part of the title. Eliminate!
    title.gsub!(/\(.*\)\s*$/, '')

    # Remove things in brackets, part of an AACR2 GMD that's made it in.
    # replace with ':' so we can keep track of the fact that everything
    # that came afterwards was a sub-title like thing. 
    title.sub!(/\[.*\]/, ':')

    # There seems to be some catoging/metadata disagreement about when to
    # use ';' for a subtitle instead of ':'. Normalize to ':'.
    # also normalize the first period, to a ':', even though it's kind of
    # different, still seperates the 'main' title from other parts. 
    title.sub!(/[\;\.]/, ':')

    if (options[:remove_subtitle])
      title.sub!(/\:(.*)$/, '')
    end

    
    
    # Change ampersands to 'and' for consistency, we see it both ways.
    title.gsub!(/\&/, 'and')
      
    # remove non-alphanumeric
    title.gsub!(/[^\w\s]/, ' ')

    # compress whitespace
    title.strip!
    title.gsub!(/\s+/, ' ')

    title.downcase!
    
    title = nil if title.blank?

    return title
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

    if ( (! ref_metadata['jtitle'].blank?) && ref_metadata['bititle'].blank? )
      hip_title_index = Hip3::BibSearcher::SERIAL_TITLE_KW_INDEX    
    else
      hip_title_index = Hip3::BibSearcher::TITLE_KW_INDEX
    end
    
    title = ref_metadata['jtitle']     
    title = ref_metadata['btitle'] if title.blank?
    title = ref_metadata['title'] if title.blank?
    
    title_cleaned = normalize_title(title)
    if title_cleaned.blank?
      # Not enough metadata to search.
      RAILS_DEFAULT_LOGGER.debug("#{self.id} is missing title, can not search.")
      return request.dispatched(self, true)
      
    end
    
    # plus remove some obvious stop words, cause HIP is going to choke on em
    title_cleaned.gsub!(/\bthe\b|\band\b|\bor\b|\bof\b|\ba\b/i,'')

    title_kws = title_cleaned.split 
    # limit to 12 keywords
    title_kws = title_kws.slice( (0..11) ) 
    
    search_hash[hip_title_index] = title_kws
    
    # If it's a non-journal thing, add the author if we have an aulast (preferred) or au. 
    # But wait--if it's a book _part_, don't include the author name, since
    # it _might_ just be the author of the part, not of the book. 
    unless (request.referent.format == "journal" ||
              ( request.referent.format == "book" &&  ! ref_metadata['atitle'].blank?))
      # prefer aulast
      if (! ref_metadata['aulast'].blank?)
        search_hash[ Hip3::BibSearcher::AUTHOR_KW_INDEX ] = [ref_metadata['aulast']]
      elsif (! ref_metadata['au'].blank?)
        search_hash[ Hip3::BibSearcher::AUTHOR_KW_INDEX ] = [ref_metadata['au']]
      end
      
    end
    
    bib_searcher.search_hash = search_hash 
    unless bib_searcher.insufficient_query
      bibs = bib_searcher.search

      # Ssee if any our matches are exact title matches. 'exact' after normalizing a bit, including removing subtitles.
      matches = [];

      requested_title = normalize_title( title, :remove_subtitle => true)

      if ( @keyword_exact_match )
        bibs.each do |bib|
          # normalize btitle to match. 
          btitle = normalize_title(bib.title, :remove_subtitle => true)            
  
          if ( btitle == requested_title && ! btitle.blank?)
            matches.push( bib )
          end        
        end
      end

      debugger
      
      responses_added = Hash.new
      
      if (matches.length > 0 )
        # process as exact matches with method from Hip3Service
        # Add copies
        # Add 856 urls.
        responses_added = {}

        unless preempted_by(request, "fulltext")
          responses_added.merge!( add_856_links(request, matches.collect{|b| b.marc_xml}, :match_reliability => ServiceResponse::MatchUnsure ) )
        end

        responses_added.merge!(  add_copies(request, matches, :match_reliability => ServiceResponse::MatchUnsure ) )
      end
      
      if (bibs.length > 0 && (! responses_added['holding']))
        # process as holdings_search
        service_data = {:service=>self}
        service_data[:source_name] = @display_name
        service_data[:count] = bibs.length
        service_data[:display_text] = "#{bibs.length} possible #{case; when bibs.length > 1 ; 'matches' ; else; 'match' ; end} in #{display_name}"

        service_data[:url] = bib_searcher.search_url

        request.add_service_response(service_data, [ServiceTypeValue[:holding_search]])
      end      
    end
    return request.dispatched(self, true)
  end


  
end
