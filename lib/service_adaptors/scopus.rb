# This is still experimental.

# Mainly finds 'cited by' from Scopus, and links to.
# Also includes an abstract, if found. 

# Register for a Scopus API key at: http://searchapi.scopus.com
# Use your Umlaut base url as the 'website url' in your registration.

class Scopus < Service
  require  'open-uri'
  require 'json'
  include MetadataHelper
  
  required_config_params :api_key

  def service_types_generated
    return [ServiceTypeValue[:cited_by], ServiceTypeValue[:abstract]]
  end

  def initialize(config)
    #defaults
    @display_name = "Scopus"
    @registered_referer
    @scopus_search_base = 'http://www.scopus.com/scsearchapi/search.url'
    @scopus_cited_by_base = 'http://www.scopus.com/scopus/search/submit/citedby.url'
    @include_abstract = true
    super(config)
  end

  def handle(request)

    
    scopus_search = scopus_search(request)

    # we can't make a good query, nevermind. 
    return request.dispatched(self, true) if scopus_search.blank? 

    
    # The default fields returned dont' include the eid (Scopus unique id) that we need, so we'll supply our own exhaustive list of &fields=
    url = 
    "#{@scopus_search_base}?devId=#{@api_key}&search=#{scopus_search}&callback=findit_callback&fields=title,doctype,citedbycount,inwardurl,sourcetitle,issn,vol,issue,page,pubdate,eid,scp,doi,firstAuth,authlist,affiliations,abstract";
    
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
    results = JSON.parse(response)

    if ( results["ERROR"])
      throw Exception.new("Error from Scopus API: #{results["ERROR"].inspect}")
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
    

    if (first_hit && first_hit["citedbycount"].to_i > 0)
      add_cited_by_response(first_hit, request)
    end

    if ( first_hit && @include_abstract && first_hit["abstract"])
      add_abstract(first_hit, request)
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
      return CGI.escape( "DOI(#{doi})" )
    elsif (pmid = get_pmid(request.referent))
      return CGI.escape( "PMID(#{pmid})" )
    elsif (isbn = get_isbn(request.referent))
      # I don't think scopus has a lot of ISBN-holding citations, but
      # it allows search so we might as well try. 
      return CGI.escape( "ISBN(#{isbn})" )
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
        query = "VOLUME(#{metadata['volume']}) AND ISSUE(#{metadata['issue']}) AND PAGEFIRST(#{metadata['spage']}) "
        if ( issn )
          query += " AND (ISSN(#{issn}) OR EISSN(#{issn}))"
        else
          query += " AND EXACTSRCTITLE(\"#{metadata['jtitle']}\")"
        end
        return CGI.escape(query)
      end
      
    end
  end

  # Input is a ruby hash that came from the scopus JSON, representing
  # a single hit. We're going to add this as a result. 
  def add_cited_by_response(result, request)
    # While scopus provides an "inwardurl" in the results, this just takes
    # us to the record detail page. We actually want to go RIGHT to the
    # list of cited-by items. So we create our own, based on Scopus's
    # reversed engineered predictable URLs. 

    count = result["citedbycount"]
    cited_by_url = cited_by_url( result )
    
    request.add_service_response(:service=>self, :display_text => "#{count} #{ServiceTypeValue[:cited_by].display_name.downcase.pluralize} in #{@display_name}", :count=> count, :url => cited_by_url, :service_type_value => :cited_by)

  end

  def add_abstract(first_hit, request)
    
    request.add_service_response( :service=>self, :display_text => "Abstract from #{@display_name}", :content => first_hit["abstract"], :url => detail_url(first_hit), :service_type_value => :abstract)
  end

  def detail_url(hash)
    url = hash["inwardurl"]
    # for some reason ampersand's in query string have wound up double escaped
    # and need to be fixed.
    url = url.gsub(/\&amp\;/, '&')

    return url
  end

  def cited_by_url(result)
    eid = result["eid"]    
    return "#{@scopus_cited_by_base}?eid=#{eid}&src=s&origin=recordpage"
  end
  
end
