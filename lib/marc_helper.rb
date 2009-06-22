

module MarcHelper

  # Takes an array of ruby MARC objects, adds ServiceResponses
  # for the 856 links contained. 
  # Returns a hash of arrays of ServiceResponse objects added, keyed
  # by service type value string. 
  def add_856_links(request, marc_records, options = {})
    options[:default_service_type] ||= "fulltext"
    options[:match_reliability] ||= ServiceResponse::MatchExact

    responses_added = Hash.new
    
    # Keep track of urls to avoid putting the exact same url in twice
    urls_seen = Array.new
    
    marc_records.each do |marc_xml|
    
      marc_xml.find_all {|f| '856' === f.tag}.each do |field|
        url = field['u']

        # No u field? Forget it.
        next if url.nil?

        # Already got it from another catalog record?
        next if urls_seen.include?(url)

        # Trying to avoid duplicates with SFX/link resolver. 
        next if  should_skip_856_link?(request, marc_xml, url)
        
        urls_seen.push(url)
        
        
        display_name = nil
        if field['y']
          display_name = field['y']
        else
          # okay let's try taking just the domain from the url
          begin
            u_obj = URI::parse( url )
            display_name = u_obj.host
          rescue Exception
          end
          # Okay, can't parse out a domain, whole url then.
          display_name = url if display_name.nil?
        end
        # But if we've got a $3, the closest MARC comes to a field
        # that explains what this actually IS, use that too please.
        display_name = field['3'] + ' from ' + display_name if field['3']

        # Build the response. 
        
        response_params = {:service=>self, :display_text=>display_name, :url=>url}
        # get all those $z subfields and put em in notes.      
        response_params[:url] = url
  
        # subfield 3 is being used for OCA records loaded in our catalog.
        response_params[:notes] =
        field.subfields.collect {|f| f.value if (f.code == 'z') }.compact.join('; ')

        is_journal = (marc_record.leader[7,1] == 's')
        unless ( field['3'] || ! is_journal ) # subfield 3 is in fact some kind of coverage note, usually 
          response_params[:notes] += "; " unless response_params[:notes].blank? 
          response_params[:notes] += "Dates of coverage unknown."
        end

        
        unless ( options[:match_reliability] == ServiceResponse::MatchExact )
          response_params[:match_reliability] = options[:match_reliability]

          response_params[:edition_str] = edition_statement(marc_xml)
        end

        # Figure out the right service type value for this, fulltext, ToC,
        # whatever.
        service_type_value = service_type_for_856( field, options ) 

        # fulltext urls from MARC are always marked as specially stupid.
        response_params[:coverage_checked] = false
        response_params[:can_link_to_article] = false

        # Some debugging info, add the 001 bibID if we have one.
        
        response_params[:debug_info] = "BibID: #{marc_xml['001'].value}" if marc_xml['001']

        
        # Add the response
        response = request.add_service_response(response_params, 
            [ service_type_value  ])
        
        responses_added[service_type_value] ||= Array.new
        responses_added[service_type_value].push(response)
      end
    end
    return responses_added
  end

  # Used by #add_856_links. Complicated logic to try and avoid
  # presenting a URL from the catalog that duplicates what SFX does,
  # but present a URL from the catalog when it's really needed.
  #
  # One reason not to include Catalog links for an article-level
  # citation, even if SFX provided no targets, is maybe SFX
  # provided no targets because SFX _knew_ that the _particular date_
  # requested is not available. The catalog doesn't know that, but
  # we don't want to show a link from the catalog that SFX really
  # already knew wasn't going to be available.
  #
  # So:
  #
  # If this is a journal, skip the URL if it matches in our
  # SFXUrl finder, because that means we think it's an SFX controlled
  # URL. But if it's not a journal, use it anyway, because it's probably
  # an e-book that is not in SFX, even if it's from a vendor who is in
  # SFX. We use MARC leader byte 7 to tell if it's a journal. Confusing enough?
  # Not yet!  Even if it is a journal, if this isn't an article-level
  # cite and there are no other full text already provided, we
  # still include. 
  def should_skip_856_link?(request, marc_record, url)
     is_journal = (marc_record.leader[7,1] == 's')

     return (  is_journal && 
               SfxUrl.sfx_controls_url?(url) && 
                !(  request.title_level_citation? &&     
                    request.get_service_type("fulltext").length == 0  
                 )
              )
  end

  # Take a ruby Marc Field object representing an 856 field,
  # decide what umlaut service type value to map it to. Fulltext, ToC, etc.
  # This is neccesarily a heuristic guess, Marc doesn't have enough granularity
  # to really let us know for sure. 
  def service_type_for_856(field, options)
    options[:default_service_type] ||= "fulltext_title_level"

    # LC records here at hopkins have "Table of contents only" in the 856$3
      # Think that's a convention from LC? 
      if (field['3'] && field['3'].downcase =~ /table of contents( only)?/)
        return "table_of_contents"
      elsif (field['3'] && field['3'].downcase =~ /description/)
        # If it contains the word 'description', it's probably an abstract.
        # That's the best we can do, sadly. 
        return "abstract"
      elsif (field['3'] && field['3'].downcase == 'sample text')
        # LC records often include these links. 
        return "excerpts"
      elsif ( field['u'] =~ /www\.loc\.gov/ )
        # Any other loc.gov link, we know it's not full text, don't put
        # it in full text field, put it as "see also". 
        return "highlighted_link"
      else
        return options[:default_service_type]
      end
  end

  # A MARC record has two dates in it, date1 and date2. Exactly
  # what they represent is something of an esoteric mystery.
  # But this will return them both, in an array. 
  def get_years(marc)
    array = []
    
    # no marc 008? Weird, but okay. 
    return array unless marc['008'] 
    
    date1 = marc['008'].value[7,4]
    date1.strip! if date1
    array.push(date1) unless date1.blank?
    
    date2 = marc['008'].value[11,4]
    date2.strip! if date2
    array.push(date2) unless date2.blank?

    return array
  end
  
  
  # From a marc record, get a string useful to display for identifying
  # which edition/version of a work this represents. 
  def edition_statement(marc, options = {})
    options[:include_repro_info] ||= true
    options[:exclude_533_fields] = ['7','f','b', 'e']

    parts = Array.new


    #245$h GMD
    unless ( marc['245'].blank? || marc['245']['h'].blank? )
      parts.push('(' + marc['245']['h'].gsub(/[^\w\s]/, '').strip.titlecase + ')')
    end

    #250
    if ( marc['250'])
      parts.push( marc['250']['a'] ) unless marc['250']['a'].blank?
      parts.push( marc['250']['b'] ) unless marc['250']['b'].blank?
    end
    
    # 260
    if ( marc['260'])
      if (marc['260']['b'] =~ /s\.n\./)
        parts.push(marc['260']['a']) unless marc['260']['a'].blank?
      else
        parts.push(marc['260']['b']) unless marc['260']['b'].blank?
      end
      parts.push( marc['260']['c'] ) unless marc['260']['c'].blank?
    end
      
    # 533
    if options[:include_repro_info] && marc['533']
      marc['533'].subfields.each do |s|
        if ( s.code == 'a' )
          parts.push('<em>' + s.value.gsub(/[^\w\s]/, '') + '</em>:'  )  
        elsif (! options[:exclude_533_fields].include?( s.code ))
          parts.push(s.value)
        end       
      end
    end
      
    return nil if parts.length == 0

    return parts.join(' ')
  end

  # AACR2 "General Material Designation" . While these are (I think?)
  # controlled, it's actually really hard to find the list. Maybe they're
  # only semi-controlled. 
  # ONE list can be found here: http://www.oclc.org/bibformats/en/onlinecataloging/default.shtm#BCGFECEG
  def gmd_values
    # 'computer file' is an old one that may still be found in data. 
    return ['activity card', 
'art original','art reproduction','braille','chart','diorama','electronic resource','computer file', 'filmstrip','flash card','game','globe','kit','manuscript','map','microform','microscope slides','model','motion picture','music','picture','realia','slide','sound recording','technical drawing','text','toy','transparency','videorecording']
  end

  # removes something that looks like an AACR2 GMD in square brackets from
  # the string. Pretty kludgey. 
  def strip_gmd(arg_string, options = {})
    options[:replacement] ||= ':'
    
    gmd_values.each do |gmd_val|
      arg_string = arg_string.sub(/\[#{gmd_val}( \((tactile|braile|large print)\))?\]/, options[:replacement])
    end
    return arg_string
  end

  
end
