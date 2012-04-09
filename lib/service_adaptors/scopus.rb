# Service adapter plug-in.
# 
# PURPOSE: Includes "cited by", "similar articles" and "more by these authors"
# links from scopus. Also will throw in an abstract from Scopus if found. 
#
# LIMTATIONS: You must be a Scopus customer for these links generated to work
# for your users at all! Off-campus users should be going through ezproxy, see
# the EZProxy plug-in.
# Must find a match in scopus, naturally. "cited by" will only
# be included if Scopus has non-0 "cited by" links. But there's no good way
# to precheck similar/more-by for this, so they are provided blind and may
# result in 0 hits.  You can turn them off if you like, with @include_similar,
# and @include_more_by_authors. 
#
# REGISTERING:  This plug in actually has to use two seperate Scopus APIs.
# For the first, the scopus 'json' search api, you must regsiter and get an
# api key from scopus, which you can do here:
# http://searchapi.scopus.com
# Then include as @json_api_key in service config.
#
# For the second Scopus API, you theoretically need a Scopus "PartnerID" and
# corresponding "release number", in @partner_id and @scopus_release
# There's no real easy way to get one. Scopus says:
#    "To obtain a partner ID or release number, contact your nearest regional
#    Scopus office. A list of Scopus contacts is available at
#    http://www.info.scopus.com/contactus/index.shtml"
# Bah! But fortunately, using the "partnerID" assigned to the Scopus Json
# API, 65, _seems_ to work, and is coded here as the default. You could try
# going with that. When you register a partnerID, you also get a 'salt key',
# which is currently not used by this code, but @link_salt_key is reserved
# for it in case added functionality does later. 
#
class Scopus < Service
  require  'open-uri'
  require 'multi_json'
  
  include ActionView::Helpers::SanitizeHelper
  
  include MetadataHelper
  include UmlautHttp
  
  required_config_params :json_api_key

  def service_types_generated
    types = []
    types.push( ServiceTypeValue[:abstract]) if @include_abstract
    types.push( ServiceTypeValue[:cited_by] ) if @include_cited_by
    types.push( ServiceTypeValue[:abstract] ) if @include_abstract
    types.push( ServiceTypeValue[:similar] ) if @include_similar
    types.push( ServiceTypeValue[@more_by_authors_type] ) if @include_more_by_authors

    return types
  end

  def initialize(config)
    #defaults
    @display_name = "Scopus"
    @registered_referer
    @scopus_search_base = 'http://www.scopus.com/scsearchapi/search.url'
    
    @include_abstract = true
    @include_cited_by = true
    @include_similar = true
    @include_more_by_authors = true
    @more_by_authors_type = "similar"

    @inward_cited_by_url = "http://www.scopus.com/scopus/inward/citedby.url"
    #@partner_id = "E5wmcMWC"
    @partner_id = 65
    @link_salt_key = nil
    @scopus_release = "R6.0.0"

    # Scopus offers two algorithms for finding similar items.
    # This variable can be:
    # "key" => keyword based similarity 
    # "ref" => reference based similiarity (cites similar refs?) Seems to offer 0 hits quite often, so we use keyword instead. 
    # "aut" => author. More docs by same authors. Incorporated as seperate link usually. 
    @more_like_this_type = "key"
    @inward_more_like_url = "http://www.scopus.com/scopus/inward/mlt.url"
    
    @credits = {
      @display_name => "http://www.scopus.com/home.url"
    }
    
    super(config)
  end

  def handle(request)
    scopus_search = scopus_search(request)

    # we can't make a good query, nevermind. 
    return request.dispatched(self, true) if scopus_search.blank? 

    
    # The default fields returned dont' include the eid (Scopus unique id) that we need, so we'll supply our own exhaustive list of &fields=
    url = 
    "#{@scopus_search_base}?devId=#{@json_api_key}&search=#{scopus_search}&callback=findit_callback&fields=title,doctype,citedbycount,inwardurl,sourcetitle,issn,vol,issue,page,pubdate,eid,scp,doi,firstAuth,authlist,affiliations,abstract";
    
    # Make the call.
    headers = {}
    headers["Referer"] = @registered_referer if @registered_referer 

    response = open(url, headers).read    
    
    # Okay, Scopus insists on using a jsonp technique to embed the json array in
    # a procedure call. We don't want that, take the actual content out of it's
    # jsonp wrapper. 
    response =~ /^\w*findit_callback\((.*)\);?$/
    response = $1;
    
    # Take the first hit from scopus's results, hope they relevancy ranked it
    # well. For DOI/pmid search, there should ordinarly be only one hit!
    results = MultiJson.decode(response)

    if ( results["ERROR"])
      Rails.logger.error("Error from Scopus API: #{results["ERROR"].inspect}   openurl: ?#{request.referent.to_context_object.kev}")
      return request.dispatched(self, false)
    end

    # For reasons not clear to me, the JSON data structures vary.
    first_hit = nil
    if ( results["PartOK"])
      first_hit = results["PartOK"]["Results"][0]
    elsif ( results["OK"] )
      first_hit = results["OK"]["Results"][0]
    else
      # error. 
    end

    if ( first_hit )
    
      if (@include_cited_by && first_hit["citedbycount"].to_i > 0)
        add_cited_by_response(first_hit, request)
      end
  
      if (@include_abstract && first_hit["abstract"])
        add_abstract(first_hit, request)
      end

      if (@include_similar)
        url = more_like_this_url(first_hit)
        # Pre-checking for actual hits not currently working, disabled.
        if (true || ( hits = check_for_hits(url) ) > 0 )
          request.add_service_response( 
            :service=>self, 
            :display_text => "#{hits} #{ServiceTypeValue[:similar].display_name_pluralize.downcase.capitalize}", 
            :url => url, 
            :service_type_value => :similar)          
        end                
      end

      if ( @include_more_by_authors)
        url = more_like_this_url(first_hit, :type => "aut")
        # Pre-checking for actual hits not currently working, disabled. 
        if (true || ( hits = check_for_hits(url) ) > 0 )
          request.add_service_response( 
            :service=>self, 
            :display_text => "#{hits} More from these authors", 
            :url => url, 
            :service_type_value => :similar)          
        end        
      end

    end

    return request.dispatched(self, true)
  end

  # Comes up with a scopus advanced search query intended to find the exact
  # known item identified by this citation.
  #
  # Will try to use DOI or PMID if available. Otherwise
  # will use issn/year/vol/iss/start page if available.
  # In some cases may resort to author/title. 
  def scopus_search(request)
    
    if (doi = get_doi(request.referent))
      return CGI.escape( "DOI(#{phrase(doi)})" )
    elsif (pmid = get_pmid(request.referent))
      return CGI.escape( "PMID(#{phrase(pmid)})" )
    elsif (isbn = get_isbn(request.referent))
      # I don't think scopus has a lot of ISBN-holding citations, but
      # it allows search so we might as well try. 
      return CGI.escape( "ISBN(#{phrase(isbn)})" )
    else            
      # Okay, we're going to try to do it on issn/vol/issue/page.
      # If we don't have issn, we'll reluctantly use journal title
      # (damn you google scholar).
      metadata = request.referent.metadata
      issn = request.referent.issn
      if ( (issn || ! metadata['jtitle'].blank? ) &&
           ! metadata['volume'].blank? &&
           ! metadata['issue'].blank? &&
           ! metadata['spage'].blank? )
        query = "VOLUME(#{phrase(metadata['volume'])}) AND ISSUE(#{phrase(metadata['issue'])}) AND PAGEFIRST(#{phrase(metadata['spage'])}) "
        if ( issn )
          query += " AND (ISSN(#{phrase(issn)}) OR EISSN(#{phrase(issn)}))"
        else
          query += " AND EXACTSRCTITLE(#{phrase(metadata['jtitle'])})"
        end
        return CGI.escape(query)
      end
      
    end
  end
  
  # backslash escapes any double quotes, and embeds string in scopus
  # phrase search double quotes. Does NOT uri-escape. 
  def phrase(str)
    '"' + str.gsub('"', '\\"') + '"'
  end

  # Input is a ruby hash that came from the scopus JSON, representing
  # a single hit. We're going to add this as a result. 
  def add_cited_by_response(result, request)
    # While scopus provides an "inwardurl" in the results, this just takes
    # us to the record detail page. We actually want to go RIGHT to the
    # list of cited-by items. So we create our own, based on Scopus's
    # reversed engineered predictable URLs. 

    count = result["citedbycount"]
    label = ServiceTypeValue[:cited_by].display_name_pluralize.downcase.capitalize    
      if count && count == 1
        label = ServiceTypeValue[:cited_by].display_name.downcase.capitalize
      end
    cited_by_url = cited_by_url( result )
    
    request.add_service_response(:service=>self, 
      :display_text => "#{count} #{label}", 
      :count=> count, 
      :url => cited_by_url, 
      :service_type_value => :cited_by)

  end

  def add_abstract(first_hit, request)

    return if first_hit["abstract"].blank?
    
    request.add_service_response( 
      :service=>self, 
      :display_text => "Abstract from #{@display_name}", 
      :content => sanitize(first_hit["abstract"]), 
      :content_html_safe => true,
      :url => detail_url(first_hit), 
      :service_type_value => :abstract)
  end

  def detail_url(hash)
    url = hash["inwardurl"]
    # for some reason ampersand's in query string have wound up double escaped
    # and need to be fixed.
    url = url.gsub(/\&amp\;/, '&')

    return url
  end

  def cited_by_url(result)
    eid = CGI.escape(result["eid"])    
    #return "#{@scopus_cited_by_base}?eid=#{eid}&src=s&origin=recordpage"
    # Use the new scopus direct link format!
    return "#{@inward_cited_by_url}?partnerID=#{@partner_id}&rel=#{@scopus_release}&eid=#{eid}"
    return 
  end

  def more_like_this_url(result, options = {})
    options[:type] ||= @more_like_this_type
    
    eid = CGI.escape(result["eid"])
    return "#{@inward_more_like_url}?partnerID=#{@partner_id}&rel=#{@scopus_release}&eid=#{eid}&mltType=#{options[:type]}"
  end

  # NOT currently working. Scopus doesn't make this easy. 
  # Takes a scopus direct url for which we're not sure if there will be results
  # or not, and requests it and html screen-scrapes to get hit count. (We
  # can conveniently find this just in the html <title> at least).
  # Works for cited_by and more_like_this searches at present. 
  # May break if Scopus changes their html title!
  def check_for_hits(url)
  
    response = http_fetch(url).body

    response_html = Nokogiri::HTML(response)

    title = response_xml.at('title').inner_text
    # title is "X documents" (or 'Documents') if there are hits.
    # It's annoyingly "Search Error" if there are either 0 hits, or
    # if there was an actual error. So we can't easily log actual
    # errors, sorry.
    title.downcase =~ /^\s*(\d+)?\s+document/
    if ( hits = $1)
      return hits.to_i
    else
      return 0
    end    
  end

    
end
