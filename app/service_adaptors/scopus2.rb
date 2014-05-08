# Service adapter plug-in.
#
# 
# PURPOSE: Includes "cited by", "similar articles" and "more by these authors"
# links from scopus. 
#
# LIMTATIONS: You must be a Scopus customer for these links generated to work
# for your users at all! Off-campus users should be probably going through ezproxy, see
# the EZProxy plug-in.
# Must find a match in scopus, naturally. "cited by" will only
# be included if Scopus has non-0 "cited by" links. But there's no good way
# to precheck similar/more-by for this, so they are provided blind and may
# result in 0 hits.  You can turn them off if you like, with @include_similar,
# and @include_more_by_authors. 
# Abstracts are not used because it seems to violate Scopus terms of service
# to use them. 
#
# REGISTERING:  Register for a Scopus API key at: 
# http://www.developers.elsevier.com/action/devprojects?pageOrigin=cmsPage&zone=topNavBar
# Look for "Register a new site" button at the bottom right of the page. 
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
# SCOPUS USEFUL URLS:
#
# api key register: http://www.developers.elsevier.com/action/devprojects?pageOrigin=cmsPage&zone=topNavBar 
#
# 'content policies' terms of use: http://www.developers.elsevier.com/cms/content-apis 
#
# API overview docs: http://www.developers.elsevier.com/cms/content-apis 
#
# Various other api docs? Confused myself as to organization here. 
#
# * http://www.developers.elsevier.com/devcms/content-api-search-request
# * http://www.developers.elsevier.com/devcms/content/search-fields-overview
# * http://api.elsevier.com/content/search/#d0n14606
#
# Some API recommendations for federated search: http://www.developers.elsevier.com/cms/restful-api-federated-search
#
class Scopus2 < Service
  require 'umlaut_http'
  require 'nokogiri'
  
  include ActionView::Helpers::SanitizeHelper
  
  include MetadataHelper
  include UmlautHttp
  
  required_config_params :api_key

  attr_accessor :scopus_search_base

  def service_types_generated
    types = []
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
    @scopus_search_base = 'http://api.elsevier.com/content/search/index:SCOPUS'
    
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

  def xml_namespaces
    @xml_namespaces ||= 
      { "atom"        => "http://www.w3.org/2005/Atom",
        "dc"          => "http://purl.org/dc/elements/1.1/",
        "opensearch"  => "http://a9.com/-/spec/opensearch/1.1/",
        "prism"       => "http://prismstandard.org/namespaces/basic/2.0/"
      }
  end

  def handle(request)
    scopus_query = scopus_query(request)

    # we can't make a good query, nevermind. 
    return request.dispatched(self, true) if scopus_query.blank? 
    
    url = scopus_url(scopus_query)
    
    
    # Make the call.
    headers = {"Accept" => "application/xml"}
    headers["Referer"] = @registered_referer if @registered_referer 

    response = http_fetch(url, :headers => headers, :raise_on_http_error_code => false)

    unless response.kind_of? Net::HTTPSuccess
      # error, sometimes we have info in XML <service-error>
      xml = begin
        Nokogiri::XML(response.body)
      rescue Exception
        nil
      end
    
      code, message = nil, nil
      if xml && error = xml.at_xpath("./service-error")
        code    = error.at_xpath("./status/statusCode")
        message = error.at_xpath("./status/statusText")
      end
      e = StandardError.new("Scopus returned error: #{code}: #{message}: scopus query: #{url}")
      return request.dispatched(self, DispatchedService::FailedFatal, e)
    end

    xml      = Nokogiri::XML(response.body)
    
    # Take the first hit from scopus's results, hope they relevancy ranked it
    # well. For DOI/pmid search, there should ordinarly be only one hit!    
    first_hit = xml.at_xpath("//atom:entry[1]", xml_namespaces)

    # Weirdly, a zero-hit result has one <atom:entry> containing an
    # <atom:error> (Sic). Could other kinds of errors be reported that
    # way too? Maybe. Better check just in case, ugh. 
    if first_hit && (error = first_hit.at_xpath("./atom:error", xml_namespaces))      
        scopus_message = error.text

        if scopus_message == "Result set was empty"
          # Just zero hits, no big deal, but nothing to do. 
          return request.dispatched(self, true)
        else
          # real error, log it. 
          e = StandardError.new("Scopus returned error: #{error.text}: scopus query: #{url}")
          return request.dispatched(self, DispatchedService::FailedFatal, e)
        end
    end 

    if first_hit
      if first_hit && (error = first_hit.at_xpath("./atom:error", xml_namespaces))      
        e = StandardError.new("Scopus returned error: #{error.text}")
        return request.dispatched(self, DispatchedService::FailedFatal, e)
      end 
    
      if (@include_cited_by)
        try_add_cited_by_response(first_hit, request)
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

  
  # Returns a scopus advanced search query intended to find the exact
  # known item identified by this citation.
  #
  # NOT uri-escaped yet, make sure to uri-escape before putting it in a uri
  # param! 
  #
  # Will try to use DOI or PMID if available. Otherwise
  # will use issn/year/vol/iss/start page if available.
  # In some cases may resort to author/title. 
  def scopus_query(request)
    
    if (doi = get_doi(request.referent))
      return "DOI(#{phrase(doi)})"
    elsif (pmid = get_pmid(request.referent))
      return "PMID(#{phrase(pmid)})"
    elsif (isbn = get_isbn(request.referent))
      # I don't think scopus has a lot of ISBN-holding citations, but
      # it allows search so we might as well try. 
      return "ISBN(#{phrase(isbn)})"
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
        return query
      end      
    end
    return nil
  end

  def scopus_url(query)
    "#{@scopus_search_base}?apiKey=#{CGI.escape @api_key}&query=#{CGI.escape query}"
  end
  
  # backslash escapes any double quotes, and embeds string in scopus
  # phrase search double quotes. Does NOT uri-escape. 
  def phrase(str)
    '"' + str.gsub('"', '\\"') + '"'
  end

  # Input is a ruby hash that came from the scopus JSON, representing
  # a single hit. We're going to add this as a result. 
  def try_add_cited_by_response(result, request)
    # While scopus provides an "inwardurl" in the results, this just takes
    # us to the record detail page. We actually want to go RIGHT to the
    # list of cited-by items. So we create our own, based on Scopus's
    # reversed engineered predictable URLs. 

    count_str = result.at_xpath("atom:citedby-count/text()", xml_namespaces).to_s
    count_i   = count_str.to_i

    return if count_i < 1
    
    label = ServiceTypeValue[:cited_by].display_name_pluralize.downcase.capitalize    
      if count_i == 1
        label = ServiceTypeValue[:cited_by].display_name.downcase.capitalize
      end
    cited_by_url = cited_by_url( result )
    
    request.add_service_response(:service=>self, 
      :display_text => "#{count_str} #{label}", 
      :count=> count_i, 
      :url => cited_by_url, 
      :service_type_value => :cited_by)
  end

  def eid_from_hit(result)
    result.at_xpath("atom:eid/text()", xml_namespaces).to_s
  end

  def cited_by_url(result)
    eid = CGI.escape( eid_from_hit(result) )    
    #return "#{@scopus_cited_by_base}?eid=#{eid}&src=s&origin=recordpage"
    # Use the new scopus direct link format!
    return "#{@inward_cited_by_url}?partnerID=#{@partner_id}&rel=#{@scopus_release}&eid=#{eid}"
    return 
  end

  def more_like_this_url(result, options = {})
    options[:type] ||= @more_like_this_type
    eid = CGI.escape eid_from_hit(result)

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
