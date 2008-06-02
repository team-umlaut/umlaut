# This service searches the Internet Archive (archive.org) by title
# and, if present, creator. Results are broken down by mediatypes. Which 
# mediatypes are searched can be configured via umlaut_config/services.yml. 
# Also an optional link to a full search in the native interface can be 
# presented to the user.

class InternetArchive < Service
  require 'open-uri' #
  require 'cgi'
  require 'json' #we ask IA for json
  include MetadataHelper
  
  # FIXME which params are required?
  #required_config_params :display_text
  attr_reader :url, :num_results, :mediatypes
  
  def service_types_generated
     return [ 
       ServiceTypeValue[:fulltext], 
       ServiceTypeValue[:audio],
       ServiceTypeValue['highlighted_link'] ]
  end
  
  def initialize(config)
    # Default base URL for IA advanced search. We use this base link rather than
    # the this rather than the IA Solr index directly because IA suggests that 
    # the Solr home may change over time.
    @url = 'http://www.archive.org/advancedsearch.php?'
    # default number of results to return
    @num_results = 3
    # default IA mediatypes to search
    @mediatypes = ["texts", "audio"]
    # Should the web link to further results be shown? default to true
    @show_web_link = true
    super(config)
  end
  
  def handle(request)
    do_query(request)    
    return request.dispatched(self, true)
  end
  
  def do_query(request)
    # get the search terms for use in both fulltext search and highlighted_link
    search_terms = get_search_terms(request.referent)
    # if there's no title we don't have enough to go on
    return nil if search_terms[:title].nil?
    @mediatypes.each do |type|
      link = @url + ia_params(search_terms, type)
      response = open(link).read
      doc = JSON.parse(response)
      results = doc['response']['docs']
      #good_results = true unless results.empty?
      
      # if we have more results than we want to show in the main view
      # we can ceate a link (highlighted_link) to the search in the sidebar 
      num_found = doc['response']['numFound']
      if @show_web_link and not results.empty? and @num_results <= num_found
        do_web_link(request, search_terms, type, num_found) 
      end
      
      # add a service response for each result for this mediatype
      results.each do |result|
        display_name = "#{@display_text} (#{type})" || "Internet Archive (#{type})"
        note = result['title']
        note << " by " << result['creator'].join(', ') if result['creator']
        service_type = [:fulltext]
        service_type = [:audio] if type == "audio"
        request.add_service_response(
          {:service=>self, 
            :display_text=>display_name, 
            :url=>create_result_url(result), 
            :notes=>note}, service_type)
      end  
    end
  end
  
  # Here we create params in the format that the IA advanced search needs.
  # These are solr-like params.
  def ia_params(search_terms, type)
    return nil if search_terms[:title].nil?
    params = 'fl%5B%5D=*&fmt=json&xmlsearch=Search' #&indent=yes
    params << "&rows=#{@num_results}&q="
    params << create_query_params(search_terms, type)   
  end
  
  def create_result_url(result)
    'http://archive.org/details/' + result['identifier']
  end
 
  def do_web_link(request, search_terms, type, num_found)
    display_text = "All #{num_found} results from the Internet Archive (#{type})"
    url = create_web_link_url(search_terms, type)
    request.add_service_response( { 
        :service=>self,    
        :url=>url,
        :display_text=>display_text}, 
        [ServiceTypeValue[:highlighted_link]]    )
  end
  
  def create_web_link_url(search_terms, type)
    'http://www.archive.org/search.php?query=' << create_query_params(search_terms, type)
    #url << CGI.escape('mediatype:' << type << ' AND ')
    
  end
  
  def create_query_params(search_terms, type)
    params = CGI.escape('title:"' << search_terms[:title] << '"')
    if search_terms[:creator]   
      params << CGI.escape(' AND creator:"' << search_terms[:creator] << '"') 
    end
    params << CGI.escape(' AND mediatype:' << type) 
  end
  
end

# Test URLs using defaults
# Shows texts and audio under fulltext, but only a see also for texts
# http://localhost:3000/resolve?&rft.title=Fairy+Tales&rft.aulast=Andersen&ctx_ver=Z39.88-2004&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook
# 
# Shows texts and audio, but only see also for audio
# http://localhost:3000/resolve?&rft.title=Frankenstein&rft.aulast=Shelley&ctx_ver=Z39.88-2004&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook
