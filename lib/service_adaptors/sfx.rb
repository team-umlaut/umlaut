# NOTE: In your SFX Admin, under Menu Configuration / API, you should enable ALL
# 'extra' API information for full umlaut functionality.
# With the exception of "Include openURL parameter", can't figure out how
# that's useful. 
#
# config parameters in services.yml
# display name: User displayable name for this service
# base_url: SFX base url. 
# click_passthrough: DEPRECATED. Caused problems. Use the SFXBackchannelRecord
#     link filter service instead. 
#     When set to true, Umlaut will send all SFX clicks
#     through SFX, for SFX to capture statistics. This is currently done
#     using a backdoor into the SFX sfxresolve.cgi script. Defaults to false. 
#     Note that
#     after SFX requests have been removed in the nightly job, the
#     click passthrough will cause an error! Set sfx_requests_expire_crontab
#     with the crontab pattern you use for requests to expire, and we won't
#     try to click passthrough with expired requests.
# sfx_requests_expire_crontab:  Crontab pattern that the SFX admin is using
#     to expire SFX requests. Used to refrain from click passthrough with
#     expired requests, since that is destined to fail. 
# services_of_interest: Optional. over-ride the built in list of what types of 
#     SFX services we want to grab, and what the corresponding umlaut types are.
#     hash, with SFX service type name as key, and Umlaut ServiceTypeValue
#     name as value. 
# extra_targets_of_interest: sfx target_names of targets you want to make
#     sure to include in umlaut. A hash with target_name as key, and umlaut
#     ResponseTypeValue name as value.
# really_distant_relationships: An array of relationship type codes from SFX 
#     "related objects".  See Table 18 in SFX 3.0 User's Manual. Related
#     objects that have only a "really distant relationship" will NOT
#     be shown as fulltext, but will instead be banished to the see also
#     "highlighted_link" section. You must have display of related objects
#     turned ON in SFX display admin, to get related objects at all in
#     Umlaut. NOTE: This parameter has a default value to a certain set of
#     relationships, set to empty array [] to eliminate defaults. 
# sfx_timeout: in seconds, for both open/read timeout value for SFX connection.
#          Defaults to 8.
# roll_up_prefixes: ARRAY of STRINGs, prefixes like "EBSCOHOST_". If multiple
#      targets sharing one of the specified prefixes are supplied from SFX,
#      they will be "rolled up" and collapsed, just the first one included
#      in response. For TITLE-LEVEL (rather than article-level) requests,
#      the roll-up algorithm is sensitive to COVERAGES, and will only suppress
#      targets that have coverages included in remaining non-suppressed targets.  
class Sfx < Service
  require 'uri'
  require 'htmlentities'
  require 'cgi'
  require 'nokogiri'
  require 'date'

  #require 'open_url'

  required_config_params :base_url
  
  def initialize(config)

    # Key is sfx service_type, value is umlaut servicetype string.
    # These are the SFX service types we will translate to umlaut
    @services_of_interest = {'getFullTxt'          => 'fulltext',
                             'getSelectedFullTxt'  => 'fulltext',
                             'getDocumentDelivery' => 'document_delivery',                         
                             'getDOI'              => 'highlighted_link',
                             'getAbstract'         => 'abstract',
                             'getTOC'              => 'table_of_contents'}

    # Special targets. Key is SFX target_name.
    # Value is umlaut service type.
    # These targets will be included even if their sfx service_type doesn't
    # match our services_of_interest, and the umlaut service ID string given
    # here will take precedence and be used even if these targets DO match
    # services_of_interest. Generally loaded from yml config in super.    
    @extra_targets_of_interest = {}

    @sfx_timeout = 8

    @really_distant_relationships = ["CONTINUES_IN_PART", "CONTINUED_IN_PART_BY", "ABSORBED_IN_PART", "ABSORBED_BY"]
    
    # Include a CrossRef credit, becuase SFX uses CrossRef api internally,
    # and CrossRef ToS may require us to give credit. 
    @credits = {
      "SFX" => "http://www.exlibrisgroup.com/sfx.htm",
      "CrossRef" => "http://www.crossref.org/"
    }
                                  
    super(config)                              
  end

  # Standard method, used by auto background updater. See Service docs. 
  def service_types_generated
    service_strings = []
    service_strings.concat( @services_of_interest.values() )
    service_strings.concat( @extra_targets_of_interest.values() )
    service_strings.uniq!

    return service_strings.collect { |s| ServiceTypeValue[s] }
  end

  def base_url
    return @base_url
  end
  
  def handle(request)
    client = self.initialize_client(request)
    begin
      response = self.do_request(client)
      self.parse_response(response, request)
      return request.dispatched(self, true)
    rescue Errno::ETIMEDOUT, Timeout::Error => e
      # Request to SFX timed out. Record this as unsuccessful in the dispatch table. Temporary.
      return request.dispatched(self, DispatchedService::FailedTemporary, e)
    end
  end
  
  def initialize_client(request)
    transport = OpenURL::Transport.new(@base_url, nil, :open_timeout => @sfx_timeout, :read_timeout => @sfx_timeout)
    
    context_object = request.to_context_object
    
    ## SFX HACK WORKAROUND
    # SFX will parse private_data/pid/rft_dat containing ERIC, when sid/rfr_id
    # is CSA. But it only expects an OpenURL 0.1 to do this. We send it a
    # 1.0. To get it to recognize it anyway, we need to send it a blank
    # url_ver/ctx_ver
    if ( context_object.referrer.identifiers.find {|i| i.start_with? "info:sid/CSA"} &&
         context_object.referent.private_data != nil)
      context_object.openurl_ver = ""
    end
    
    transport.add_context_object(context_object)
    transport.extra_args["sfx.response_type"]="multi_obj_xml"
      
    @get_coverage = false    
    
    metadata = request.referent.metadata    
    if ( metadata['date'].blank? &&
         metadata['year'].blank? &&
         (! request.referent.identifiers.find {|i| i =~ /^info\:(doi|pmid)/})
        )
      # No article-level metadata, do some special stuff. 
      transport.extra_args["sfx.ignore_date_threshold"]="1"
      transport.extra_args["sfx.show_availability"]="1"
      @get_coverage = true
    end
    # Workaround to SFX bug, not sure if this is really still neccesary
    # I think it's not, but leave it in anyway just in case. 
    if (context_object.referent.identifiers.find {|i| i =~ /^info:doi\// })
      transport.extra_args['sfx.doi_url']='http://dx.doi.org'
    end
    
    return transport
  end
  
  def do_request(client)
    client.transport_inline    
    return client.response
  end
  
  def parse_response(resolver_response, request)
    doc = Nokogiri::XML(resolver_response)     

    # Catch an SFX error message (in HTML) that's not an XML
    # document at all.
    unless doc.at('/ctx_obj_set')
      Rails.logger.error("sfx.rb: SFX did not return expected response. SFX response: #{resolver_response}")
      raise "SFX did not return expected response."
    end

    # There can be several context objects in the response.
    # We need to keep track of which data comes from which, for
    # SFX click-through generating et alia
    sfx_objs = doc.search('/ctx_obj_set/ctx_obj')

    # As we go through the possibly multiple SFX context objects,
    # we need to keep track of which one, if any, we want to use
    # to enhance the Umlaut referent metadata.
    #
    # We only enhance for journal type metadata. For book type
    # metadata SFX will return something, but it may not be the manifestation
    # we want. With journal titles, less of an issue. 
    #
    # In case of multiple SFX hits, enhance metadata only from the
    # one that actually had fulltext. If more than one had fulltext, forget it,
    # too error prone. If none had full text, just pick the first. 
    #
    # We'll use these variables to keep track of our 'best fit' as
    # we loop through em.     
    best_fulltext_ctx = nil
    best_nofulltext_ctx = nil

    # We're going to keep our @really_distant_relationship stuff here. 
    related_titles = {}
    
    # We organize our responses in a queue, so we can process them
    # for collapse function, before actually writing to db. 
    response_queue ||= {}
    
    0.upto(sfx_objs.length - 1 ) do |sfx_obj_index|
    
      sfx_obj = sfx_objs[sfx_obj_index]

      # Get out the "perl_data" section, with our actual OpenURL style
      # context object information. This was XML escaped as a String (actually
      # double-escaped, weirdly), so
      # we need to extract the string, unescape it, and then feed it to Nokogiri
      # again. 
      ctx_obj_atts = sfx_obj.at('./ctx_obj_attributes').inner_text

      perl_data = Nokogiri::XML( ctx_obj_atts )
      # parse it into an OpenURL, we might need it like that. 
      sfx_co = Sfx.parse_perl_data(perl_data)
      sfx_metadata = sfx_co.to_hash 

      
      # get SFX objectID
      object_id_node =
        perl_data.at("./perldata/hash/item[@key='rft.object_id']")
      object_id = object_id_node ? object_id_node.inner_text : nil

      # Get SFX requestID
       request_id_node = 
         perl_data.at("./perldata/hash/item[@key='sfx.request_id']")
       request_id = request_id_node ? request_id_node.inner_text : nil
      
      # Get targets service ids
      sfx_target_service_ids =
        sfx_obj.search('ctx_obj_targets/target/target_service_id').collect {|e| e.inner_text}


      
      metadata = request.referent.metadata
            
      # For each target delivered by SFX
      sfx_obj.search("./ctx_obj_targets/target").each_with_index do|target, target_index|  
        response_data = {}
  
        # First check @extra_targets_of_interest
        sfx_target_name = target.at('./target_name').inner_text
        umlaut_service = @extra_targets_of_interest[sfx_target_name]
  
        # If not found, look for it in services_of_interest
        unless ( umlaut_service )
          sfx_service_type = target.at("./service_type").inner_text
          umlaut_service = @services_of_interest[sfx_service_type]
        end

        # If we have multiple context objs, skip the ill and ask-a-librarian
        # links for all but the first, to avoid dups. This is a bit messy,
        # but this whole multiple hits thing is messy.
        if ( sfx_obj_index > 0 &&
             ( umlaut_service == 'document_delivery' || 
               umlaut_service == 'export_citation' || 
               umlaut_service == 'help'))
            next
        end
        
        
        # Okay, keep track of best fit ctx for metadata enhancement
        if request.referent.format == "journal"
          if ( umlaut_service == 'fulltext')
            best_fulltext_ctx = perl_data
            best_nofulltext_ctx = nil
          elsif best_nofulltext_ctx == nil
            best_nofulltext_ctx = perl_data
          end
        end
        
        if ( umlaut_service ) # Okay, it's in services or targets of interest
          if (target/"./displayer")
            source = "SFX/"+(target/"./displayer").inner_text
          else
            source = "SFX"+URI.parse(self.url).path
          end
  
          target_service_id = (target/"./target_service_id").inner_text
          
          coverage = nil
          if ( @get_coverage )
            # Make sure you turn on "Include availability info in text format"
            # in the SFX Admin API configuration.             
            thresholds_str = ""
            target.search('coverage/coverage_text/threshold_text/coverage_statement').each do | threshold |
                thresholds_str += threshold.inner_text.to_s + ".\n";              
            end

            embargoes_str = "";
            target.search('coverage/coverage_text/embargo_text/embargo_statement').each do |embargo |
                embargoes_str += embargo.inner_text.to_s + ".\n";
            end
            
            unless ( thresholds_str.blank? && embargoes_str.blank? )
              coverage = thresholds_str + embargoes_str
            end
          end


          related_note = ""
          # If this is from a related object, add that on as a note too...
          # And maybe skip this entirely! 
          if (related_node = target.at('./related_service_info'))
            relationship = related_node.at('./relation_type').inner_text
            issn = related_node.at('./related_object_issn').inner_text
            sfx_object_id = related_node.at('./related_object_id').inner_text
            title = related_node.at('./related_object_title').inner_text
            
            if @really_distant_relationships.include?(
              related_node.at('./relation_type').inner_text)
              # Show title-level link in see-also instead of full text.
              related_titles[issn] = {
                :sfx_object_id => sfx_object_id,
                :title => title,
                :relationship => relationship,
                :issn => issn
              }
              
              next
            end
            
            related_note = "This version provided from related title:  <em>" + CGI.unescapeHTML( title ) + "</em>.\n"
          end
  
          if ( sfx_service_type == 'getDocumentDelivery' )
            value_string = request_id
          else
            value_string = (target/"./target_service_id").inner_text          
          end

          response_data[:url] = CGI.unescapeHTML((target/"./target_url").inner_text)
          response_data[:notes] = related_note.to_s + CGI.unescapeHTML((target/"./note").inner_text)
          response_data[:authentication] = CGI.unescapeHTML((target/"./authentication").inner_text)
          response_data[:source] = source
          response_data[:coverage] = coverage if coverage
          
          
          # machine actionable coverage elements, used for collapsing    
          ( response_data[:coverage_begin_date], response_data[:coverage_end_date] ) =
            determine_coverage_boundaries(target)
          
          
          # Sfx metadata we want
          response_data[:sfx_base_url] = @base_url
          response_data[:sfx_obj_index] = sfx_obj_index + 1 # sfx is 1 indexed
          response_data[:sfx_target_index] = target_index + 1
          # sometimes the sfx.request_id is missing, go figure. 
          if request_id = (perl_data/"//hash/item[@key='sfx.request_id']").first
            response_data[:sfx_request_id] = request_id.inner_text
          end
          response_data[:sfx_target_service_id] = target_service_id
          response_data[:sfx_target_name] = sfx_target_name
          # At url-generation time, the request isn't available to us anymore,
          # so we better store this citation info here now, since we need it
          # for sfx click passthrough
          
          # Oops, need to take this from SFX delivered metadata.
          
          response_data[:citation_year] = sfx_metadata['rft.date'].to_s[0,4] if sfx_metadata['rft.date'] 
          response_data[:citation_volume] = sfx_metadata['rft.volume'];
          response_data[:citation_issue] = sfx_metadata['rft.issue']
          response_data[:citation_spage] = sfx_metadata['rft.spage']

          # Some debug info
          response_data[:debug_info] =" Target: #{sfx_target_name} ; SFX object ID: #{object_id}"
          
          response_data[:display_text] = (target/"./target_public_name").inner_text
        
          response_data.merge!(
            :service => self,              
            :service_type_value => umlaut_service
          )
                                
          #request.add_service_response( response_data )
          # We add the response_data to a list for now, so we can post-process
          # for collapse feature  before we actually add them. 
          response_queue[umlaut_service] ||= []
          response_queue[umlaut_service] << response_data
              
                              
        end
      end
    end

    if response_queue["fulltext"].present?
      response_queue["fulltext"] = roll_up_responses(response_queue["fulltext"], :coverage_sensitive => request.title_level_citation? )
    end
              
    # Now that they've been post-processed, actually commit them. 
    response_queue.each_pair do |type, list|
      list.each do |response|      
        request.add_service_response( response )
      end
    end
    
    # Add in links to our related titles
    related_titles.each_pair do |issn, hash|
      request.add_service_response(        
         :service => self,
         :display_text => "#{sfx_relationship_display(hash[:relationship])}: #{hash[:title]}",
         :notes => "#{ServiceTypeValue['fulltext'].display_name} available",
         :related_object_hash => hash, 
         :service_type_value => "highlighted_link")
    end
    
    # Did we find a ctx best fit for enhancement?
    if best_fulltext_ctx
      enhance_referent(request, best_fulltext_ctx)
    elsif best_nofulltext_ctx
      enhance_referent(request, best_nofulltext_ctx)
    end
    
  end

  # pass in a nokogiri element for <target>, we'll calculate 
  # ruby Date objects for begin date and end date of coverage,
  # passed out as a two-element array [begin, end]. 
  #
  # taking embargoes into account. nil if unbounded. 
  def determine_coverage_boundaries(target)    
    # machine actionable coverage elements, used for collapsing
    if (in_node = target.at_xpath("./coverage/in"))
        year = in_node.at_xpath("year").try(:text).try(:to_i)
        if year && year != 0
          begin_date = Date.new(year, 1, 1)
          end_date   = Date.new(year, 12, 31)
        end
    end
    
    if (from = target.at_xpath("./coverage/from"))            
      year   = from.at_xpath("year").try(:text).try(:to_i)     
      # SFX KB does not have month/day, only year, set to begin of year
      begin_date = Date.new(year, 1, 1) if year && year != 0
    end
    
    if (from = target.at_xpath("./coverage/to"))            
      year   = from.at_xpath("year").try(:text).try(:to_i)
      # set to end of year
      end_date = Date.new(year, 12, 31) if year && year != 0
    end
    
    
            
    # If there's an embargo too, it may modify existing dates
    if (embargo = target.at_xpath("./coverage/embargo"))
      days = embargo.at_xpath("days").try(:text).try(:to_i)
      days.try do |days|
        embargo_days = Date.today - days
        if embargo.at_xpath("availability").try(:text) == "available"
          # only most recent X days, at earliest start                
          begin_date = 
            [begin_date || embargo_days, embargo_days].max                
        else # not_available
          # stops at most recent X days, at latest end
          end_date = 
            [end_date || embargo_days, embargo_days].min
        end
      end
    end
    return [begin_date, end_date]
  end
  
  # Pass in a list of hashes for making ServiceResponse's, we will roll up
  # those that should be rolled up per roll_up_prefixes configuration.
  #
  # In :coverage_sensitive => true, will roll up sensitive to overlapping
  # coverage to not remove any coverage. 
  #
  # Does not mutate list passed in, don't try to change it to mutate,
  # makes it hard to deal with list changing from underneath you in logic. 
  def roll_up_responses(list, options = {})
    options = options.reverse_merge(:coverage_sensitive => true)
    
    prefixes = @roll_up_prefixes
    
    # If not configured for roll-up, just return it directly. 
    return list unless prefixes.present?

    
    if options[:coverage_sensitive] == true
      # roll up targets with same prefix only if coverage is a strict
      # subset of an existing one. If two are equal, take first.       
      list = list.reject.each_with_index do |item, index|
        prefix = prefixes.find {|p| item[:sfx_target_name].start_with?(p)}        
        bdate = item[:coverage_begin_date] || Date.new(1,1,1)
        edate = item[:coverage_end_date] || Date.today
        
        prefix && (
          # earlier is equal or superset
          list.slice(0, index).find do |candidate|
            # nil considered very early or very late, unbounded
            candidate_bdate = candidate[:coverage_begin_date] || Date.new(1,1,1)
            candidate_edate = candidate[:coverage_end_date]   || Date.today
            
            candidate[:sfx_target_name].start_with?(prefix) &&
            (candidate_bdate <= bdate) && (candidate_edate >= edate)
          end ||
          # later is superset, not equal
          list.slice(index+1, list.length).find do |candidate|
            candidate_bdate = (candidate[:coverage_begin_date] || Date.new(1,1,1))
            candidate_edate = (candidate[:coverage_end_date]   || Date.today)
                                                
            candidate[:sfx_target_name].start_with?(prefix) &&
            (candidate_bdate <= bdate) && (candidate_edate >= edate) &&
            (! (bdate == candidate_bdate && edate == candidate_edate))
          end
          )
      end            
    else # not coverage_sensitive
      # Just roll up to FIRST of each prefix
      list = list.reject.each_with_index do |item, index|
        prefix = prefixes.find {|p| item[:sfx_target_name].start_with?(p)}
        
        prefix && list.slice(0,index).find do |candidate|
          candidate[:sfx_target_name].start_with?(prefix)
        end      
      end
    end
    
    
    return list
  end
  
   
  def sfx_click_passthrough
    # From config, or default to false. 
    return @click_passthrough  || false;
  end

  # Using the value of sfx_request_expire_crontab, determine if the
  # umlaut service response is so old that we can't use it for
  # sfx click passthrough anymore. 
  def expired_sfx_request(response)
    require 'CronTab'

    crontab_str = @sfx_requests_expire_crontab

    return false unless crontab_str # no param, no determination possible
    
    crontab = CronTab.new( crontab_str )

    time_of_response = response.created_at

    return false unless time_of_response # no recorded time, not possible either

    expire_time = crontab.nexttime( time_of_response )

    # Give an extra five minutes of time, in case the expire
    # process takes up to five minutes to finish. 
    return( Time.now > (expire_time + 5.minutes) )    
  end

  # Try to provide a weird reverse-engineered url to take the user THROUGH
  # sfx to their destination, so sfx will capture for statistics.
  # This relies on certain information from the orignal sfx response
  # being stored in the Response object at that point. Used by
  # sfx_backchannel_record service. 
  def self.pass_through_url(response)
    base_url = response[:sfx_base_url]    
    
    sfx_resolver_cgi_url =  base_url + "/cgi/core/sfxresolver.cgi"      

    
    dataString = "?tmp_ctx_svc_id=#{response[:sfx_target_index]}"
    dataString += "&tmp_ctx_obj_id=#{response[:sfx_obj_index]}"

    # Don't understand what this is, but it sometimes needs to be 1?
    # Hopefully it won't mess anything up when it's not neccesary.
    # Really have no idea when it would need to be something other
    # than 1.
    # Nope, sad to say it does mess up cases where it is not neccesary.
    # Grr. 
    #dataString += "&tmp_parent_ctx_obj_id=1"
    
    dataString += "&service_id=#{response[:sfx_target_service_id]}"
    dataString += "&request_id=#{response[:sfx_request_id]}"
    dataString += "&rft.year="
    dataString += URI.escape(response[:citation_year].to_s) if response[:citation_year]
    dataString += "&rft.volume="
    dataString += URI.escape(response[:citation_volume].to_s) if response[:citation_volume]
    dataString += "&rft.issue="
    dataString += URI.escape(response[:citation_issue].to_s) if response[:citation_issue]
    dataString += "&rft.spage="
    dataString += URI.escape(response[:citation_spage]).to_s if response[:citation_spage]
    
      return sfx_resolver_cgi_url + dataString       
  end

  # Class method to parse a perl_data block as XML in String
  # into a ContextObject. Argument is Nokogiri doc containing
  # the SFX <perldata> element and children. 
  def self.parse_perl_data(doc)        

    co = OpenURL::ContextObject.new
    co.referent.set_format('journal') # default

    html_ent_coder = HTMLEntities.new 
    
    doc.search('perldata/hash/item').each do |item|
      key = item['key'].to_s
            
      value = item.inner_text
      
      # SFX sometimes returns invalid UTF8 (is it really ISO 8859? Is it
      # predictable? Who knows. If it's not valid, it'll cause all
      # sorts of problems later. So if it's not valid, we're just
      # going to ignore it, sorry. 
      next unless value.valid_encoding?

      # Some normalization. SFX uses rft.year, which is not actually
      # legal. Stick it in rft.date instead.
      key = "rft.date" if key == "rft.year"

      prefix, stripped = key.split('.')
            
      # The auinit1 value is COMPLETELY messed up for reasons I do not know.
      # Double encoded in bizarre ways.
      next if key == '@rft.auinit1' || key == '@rft.auinit'



      
      # Darn multi-value SFX hackery, indicated with keys beginning
      # with '@'. Just take the first one,
      # our context object can't store more than one. Then regularize the
      # key name. 
      if (prefix == '@rft')
        array_items = item.search("array/item")
        array_i = array_items[0] unless array_items.blank?
        
        prefix = prefix.slice(1, prefix.length)
        value = array_i ? array_i.inner_text : nil   
      end
      
      # But this still has HTML entities in it sometimes. Now we've
      # got to decode THAT.
      # TODO: Are we sure we need to do this? We need an example
      # from SFX result to test, it's potentially expensive.       
      value = html_ent_coder.decode(value)

      # object_type? Fix that to be the right way.
      if (prefix=='rft') && (key=='object_type')
        co.referent.set_format( value.downcase )
        next
      end
      
      if (prefix == 'rft' && value)
          co.referent.set_metadata(stripped, value)
      end

      if (prefix=='@rft_id')
          identifiers = item.search('array/item')
          identifiers.each do |id|
            co.referent.add_identifier(id.inner_text)
          end
      end
      if (prefix=='@rfr_id')
          identifiers = item.search('array/item')
          identifiers.each do |id|
            co.referrer.add_identifier(id.inner_text)
          end
      end
    end
    return co
  end

  # Custom url generation for the weird case 
  def response_url(service_response, submitted_params)
    if (related_object =  service_response.data_values[:related_object_hash])
      {:controller => 'resolve', "rft.issn" => related_object[:issn], "rft.title" => related_object[:title], "rft.object_id" => related_object[:sfx_object_id] }
    else
      service_response['url']
    end        
  end
  
  protected
  # Second argument is a Nokogiri element representing the <perldata>
  # tag and children. 
  def enhance_referent(request, perl_data)
    ActiveRecord::Base.connection_pool.with_connection do
      metadata = request.referent.metadata
  
      sfx_co = Sfx.parse_perl_data(perl_data)
      
      sfx_metadata = sfx_co.referent.metadata
      # Do NOT enhance for metadata type 'BOOK', unreliable matching from
      # SFX!
      return if sfx_metadata["object_type"] == "BOOK" || sfx_metadata["genre"] == "book"
      
      # If we already had metadata for journal title and the SFX one
      # differs, we want to over-write it. This is good for ambiguous
      # incoming OpenURLs, among other things.
      
      if request.referent.format == 'journal'
          request.referent.enhance_referent("jtitle", sfx_metadata['jtitle'])
      end
      # And ISSN
      if request.referent.format == 'journal' && ! sfx_metadata['issn'].blank?
        request.referent.enhance_referent('issn', sfx_metadata['issn'])
      end
  
  
      # The rest,  we write only if blank, we don't over-write
      sfx_metadata.each do |key, value|
        if (metadata[key].blank?)
          
          # watch out for SFX's weird array values. 
            request.referent.enhance_referent(key, value)
        end
      end
    end                        
  end


  
  # From Table 18 in SFX General User's Guide 3.0. 
  def sfx_relationship_display(sfx_code)
    sfx_code = sfx_code.to_s
    # Most can simply be #humanized, a couple of over-rides
    @sfx_relationship_display ||= {
      "TRANSLATION_ENTRY" => "Translation",          
    }

    display = @sfx_relationship_display[sfx_code]
    display = sfx_code.humanize if display.nil?

    return display
  end
  
  end
  
