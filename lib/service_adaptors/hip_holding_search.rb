

class HipHoldingSearch < Hip3Service
  required_config_params :base_path, :display_name
  attr_reader :base_path

  include MarcHelper

  def initialize(config)
    # Default preemption by any holding
    @bib_limit = 4
    @preempted_by = { "existing_type" => "holding" }
    @keyword_exact_match = true
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

  def service_types_generated
    # Add one more to whatever the Hip3Service does. 
    return super.push(ServiceTypeValue['holding_search'])    
  end

  
  def handle(request)
    
    # Only do anything if we have no holdings results from someone else.
    holdings = request.service_types.find(:all, :conditions=>["service_type_value_name = ?", "holding"])
    
    if (holdings.length > 0)
      return request.dispatched(self, true)
    end

    ref_metadata = request.referent.metadata
    
    bib_searcher = Hip3::BibSearcher.new(@base_path)

    search_hash = {}

    if ( request.referent.format != "book" && 
        (! ref_metadata['jtitle'].blank?) && 
        ref_metadata['bititle'].blank? )
      hip_title_index = Hip3::BibSearcher::SERIAL_TITLE_KW_INDEX    
    else
      hip_title_index = Hip3::BibSearcher::TITLE_KW_INDEX
    end
    
    title = ref_metadata['jtitle']     
    title = ref_metadata['btitle'] if title.blank?
    title = ref_metadata['title'] if title.blank?
    
    #title_terms = search_terms_for_title_tokenized(title)
    # tokenized was too much recall, not enough precision. Try phrase
    # search. 
    title_terms = search_terms_for_title_phrase(title)
    unless ( title_terms )
      Rails.logger.debug("#{self.service_id} is missing title, can not search.")
      return request.dispatched(self, true)
    end
    
    
    search_hash[hip_title_index] = title_terms

    # Do we have the bibnum?
    bibnum = get_bibnum(request.referent) 
    bib_searcher.bibnum = bibnum if bibnum 
    
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
      timing_debug("start search")
      
      bibs = bib_searcher.search

      timing_debug("bib searching")

      # Ssee if any our matches are exact title matches. 'exact' after normalizing a bit, including removing subtitles.
      matches = [];

      # Various variant normalized forms of the title from the OpenURL
      # request. #compact removes nil values. 
      request_titles = [title, 
                       normalize_title( title ), 
                       normalize_title( title, :remove_subtitle => true)   ].compact
      


      if ( @keyword_exact_match )
        bibs.each do |bib|
          # various variant normalized forms of the title from the bib
          # #compact removes nil values. 
          bib_titles = [ bib.title, 
                         normalize_title(bib.title, :remove_subtitle => true),
                         normalize_title(bib.title) ].compact

          # Do any of the various forms match? Set intersection on our
          # two sets.
          if ( bib_titles & request_titles ).length > 0
            matches.push( bib )
          end        
        end
      end
      
      responses_added = Hash.new

      timing_debug("Finding matches")
      
      if (matches.length > 0 )
        
        # process as exact matches with method from Hip3Service
        # Add copies
        # Add 856 urls.
        responses_added = {}

        unless preempted_by(request, "fulltext")

          # Let's do some analysis of our results. If it's got a matching
          # bibnum, then include it as an EXACT match.
          req_bibnum = get_bibnum(request.referent)
          if ( req_bibnum )
            matches.each do |bib|
              if (req_bibnum == bib.bibNum)
                responses_added.merge!( add_856_links(request, [bib.marc_xml])  )
                responses_added.merge!( add_copies( request, [bib] ))
                matches.delete(bib)
              end                                            
            end
          end

          timing_debug("Identified matches")
          
          # Otherwise, sort records with matching dates FIRST.
          # Some link generators use an illegal 'year' parameter, bah. 
          if ( date = (request.referent['date'] || request.referent['year']))
            req_year = date[0,4]
            matches = matches.partition {|bib| get_years(bib.marc_xml).include?( req_year )}.flatten            
          end

          timing_debug("Date sorted")
          
          responses_added.merge!( add_856_links(request, matches.collect{|b| b.marc_xml}, :match_reliability => ServiceResponse::MatchUnsure ) )

          timing_debug("added 856's")
        end

        responses_added.merge!(  add_copies(request, matches, :match_reliability => ServiceResponse::MatchUnsure ) )

        timing_debug("added copies")
        
      end
      
      if (bibs.length > 0 && (! responses_added['holding']))
        # process as holdings_search      
        request.add_service_response(
          :service => self,
          :source_name => @display_name,
          :count => bibs.length,
          :display_text => "#{bibs.length} possible #{case; when bibs.length > 1 ; 'matches' ; else; 'match' ; end} in #{display_name}",
          :url => bib_searcher.search_url,
          :service_type_value => :holding_search)
      end      
    end
    return request.dispatched(self, true)
  end

  # One algorithm for turning a title into HIP search terms.
  # Tokenizes the title into individual words, eliminates stop-words,
  # and combines each word with 'AND'. We started with this for maximum
  # recall, but after some experimentation seems to have too low precision
  # without sufficient enough increase in recall.
  # Returns an array of keywords. 
  def search_terms_for_title_tokenized(title)
    title_cleaned = normalize_title(title)
    
    if title_cleaned.blank?
      # Not enough metadata to search.
      return nil      
    end
    
    # plus remove some obvious stop words, cause HIP is going to choke on em
    title_cleaned.gsub!(/\bthe\b|\band\b|\bor\b|\bof\b|\ba\b/i,'')

    title_kws = title_cleaned.split 
    # limit to 12 keywords
    title_kws = title_kws.slice( (0..11) )

    return title_kws
  end

  # Another algorithm for turning a title into HIP search terms.
  # This one doesn't tokenize, but keeps the whole title as a phrase
  # search. Does eliminate punctuation. Does not remove things that
  # look like a sub-title. 
  # Returns an array with one item.
  def search_terms_for_title_phrase(title)
    title_cleaned = normalize_title(title)

    if title_cleaned.blank?
      # Not enough metadata to search.
      return nil      
    end

    return [title_cleaned]    
  end

  def timing_debug(waypoint = "Waypoint")
    @last_timed ||= Time.now

    before = @last_timed
    @last_timed = Time.now

    interval = @last_timed - before

    Rails.logger.debug("#{service_id}: #{waypoint}: #{interval}")
    
  end
  
end
