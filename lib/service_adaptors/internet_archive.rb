# This service searches the Internet Archive (archive.org) by title
# and, if present, creator. Results are broken down by mediatypes. Which 
# mediatypes are searched can be configured via umlaut_config/services.yml. 
# Also an optional link to a full search in the native interface can be 
# presented to the user.

# Property settings can be set in services.yml
# url: 
# num_results: a number. This is the number of results returned for each 
#   mediatype within the main section of the view
# mediatypes: an array of the mediatypes searched. insure there is an
#   appropriate mediatype as defined by IA. Searching by mediatype searches
#   across collections. 
#   The following link will (currently) show the possible mediatypes:
#   http://homeserver7.us.archive.org:8983/solr/select?q=[*+TO+*]&fl=identifier&wt=json&rows=0&indent=yes&facet=true&facet.field=mediatype
# show_web_link: boolean. If set to true, if there are more results than 
#   num_results a link to those further results will display
#   with highlighted_links
# display_name: defaults to "Internet Archive"


class InternetArchive < Service
  require 'open-uri' #
  require 'cgi'
  require 'multi_json' #we ask IA for json
  require 'timeout' # used to timeout our requests
  include MetadataHelper
  
  # No parameters are required, we have working defaults for them all. 
  
  attr_reader :url, :num_results, :mediatypes  
  
  # maps the IA mediatype to Umlaut service type
  SERVICE_TYPE_MAP = {
    "texts" => :fulltext,
    "audio" => :audio
  }
  
  def service_types_generated
    types = [ 
      ServiceTypeValue[:fulltext], 
      ServiceTypeValue[:audio],
      ServiceTypeValue[:'highlighted_link']      
      ]
    types << ServiceTypeValue[:search_inside] if @include_search_inside
    return types
  end
  
  def initialize(config)
    # Default base URL for IA advanced search. We use this base link rather than
    # the this rather than the IA Solr index directly because IA suggests that 
    # the Solr home may change over time.
    @url = 'http://www.archive.org/advancedsearch.php?'
    # default number of results to return
    @num_results = 1
    # default IA mediatypes to search
    @mediatypes = ["texts", "audio"]
    # Should the web link to further results be shown? default to true
    @show_web_link = true
    @display_name = "the Internet Archive"
    @http_timeout = 5.seconds
    @include_search_inside = false
    
    @credits = {
      "The Internet Archive" => "http://archive.org/"
    }
    
    super(config)
    @num_results_for_types ||= {}
    @mediatypes.each do |type|
      @num_results_for_types[type] ||= @num_results
    end
  end
  
  def handle(request)
    begin
      do_query(request)
    rescue Timeout::Error => e
      return request.dispatched(self, false, e)
    end
    return request.dispatched(self, true)
  end
  
  def do_query(request)
    # get the search terms for use in both fulltext search and highlighted_link
    # IA does index apostrophes, although not generally other puncutation. Need to keep em.
    search_terms = {:title => get_search_title(request.referent ,:keep_apostrophes=>true),
    :creator => get_search_creator(request.referent)}
    

    
    # We need both title and author to continue
    return nil if (search_terms[:title].blank? || search_terms[:creator].blank?)

    # Return if this is an journal article link, an IA search can do nothing
    # for us except waste CPU cycles for us and IA.
    metadata = request.referent.metadata
    return nil unless metadata["atitle"].blank? &&
                      metadata["issue"].blank? &&
                      metadata["volume"].blank?
    
    # create one link that searches all configured mediatypes
    link = @url + ia_params(search_terms)
    
    # using open() conveniently follows the redirect for us. Alas, it
    # doesn't give us access to the IA http status code response though.
    response = nil
    timeout(@http_timeout.to_i) {
      response = open(link).read
    }
    debugger
    if response.blank?
      raise Exception.new("InternetArchive returned empty response for #{link}")      
    end
    
    
    doc = MultiJson.load(response)
    results = doc['response']['docs']
    
    @mediatypes.each do |type|
     type_results = get_results_by_type(results, type)



     
      # if we have more results than we want to show in the main view
      # we can ceate a link (highlighted_link) to the search in the sidebar 
      num_found = type_results.length #doc['response']['numFound']
      if (@show_web_link and not type_results.empty? and @num_results_for_types[type] < num_found )
        do_web_link(request, search_terms, type, num_found) 
      end

      # Check for search inside only for first result of type 'text'
      if (@include_search_inside &&
          type == 'texts' &&
          (first_hit = type_results[0]) && 
          (identifier = first_hit["identifier"])
          )
        direct_url = URI.parse("http://www.archive.org/stream/" + identifier)

        # Head request, if we get a 200, we think it means we have page
        # turner with search.
        req = Net::HTTP.new(direct_url.host, direct_url.port)
        response = req.request_head(direct_url.path)
        if response.code == "200"
          # search inside!
          request.add_service_response(
            :service => self,
            :display_text=> @display_name,
            :url => direct_url.to_s,
            :service_type_value => :search_inside
          )
        end        
      end
      
      # add a service response for each result for this mediatype
      type_results.each_with_index do |result, index|
        break if index == @num_results_for_types[type] 
        display_name = @display_name
        
        if ( result["collection"] && COLLECTION_LABELS[result["collection"][0]])
          display_name += ": " + COLLECTION_LABELS[result["collection"][0]]
        elsif ( result["collection"])
          display_name += ": " + result["collection"][0].titlecase
        end
        
        #note = result['title']
        #note << " by " << result['creator'].join(', ') if result['creator']

        service_type = SERVICE_TYPE_MAP[type]
        request.add_service_response(
            :service=>self, 
            :display_text=>display_name, 
            :url=>create_result_url(result),
            :match_reliability => ServiceResponse::MatchUnsure,
            :edition_str => edition_str(result),
            :service_type_value => service_type )
      end  
    end
  end
  
  # Here we create params in the format that the IA advanced search needs.
  # These are solr-like params.
  def ia_params(search_terms)
    return nil if search_terms[:title].nil?
    params = 'fl%5B%5D=*&fmt=json&xmlsearch=Search' #&indent=yes
    params << "&rows=999&q=" #is 999 too many or even too few?
    params << create_query_params(search_terms)   
  end
  
  def create_result_url(result)
    'http://archive.org/details/' + result['identifier']
  end
 
  # displaying the num_found relies on the number of results from ia_params being 
  # enough to capture all results for a mediatype. If there are more potential
  # results then num_found will not be accurate. But good enough. 
  def do_web_link(request, search_terms, type, num_found)
    display_text = "#{num_found} digital #{type.singularize} " + (num_found > 1 ? "files" : "file")

    
    url = create_web_link_url(search_terms, type)
    request.add_service_response(  
        :service=>self,    
        :url=>url,
        :display_text=>display_text, 
        :service_type_value => :highlighted_link   
     )
  end
  
  def create_web_link_url(search_terms, type)
    'http://www.archive.org/search.php?query=' << create_query_params(search_terms, type)
    #url << CGI.escape('mediatype:' << type << ' AND ')
    
  end
  
  # if given a type it will only search for one mediatype. otherwise it 
  # does an OR search for all configured mediatypes
  def create_query_params(search_terms, type=nil)
    # Downcase params to avoid weird misconfiguration in IA's SOLR
    # installation, where it's interpreting uppercase words as
    # commands even within quotes. Also take out any parens in input.
    # Also IA does not semi-colons in input?!?
    title = safe_argument(search_terms[:title])
    
    
    params = 'title:' << CGI.escape('"' << title << '"')
    if (! search_terms[:creator].blank?)
      creator = safe_argument(search_terms[:creator])      
      params << '+AND+creator:' << CGI.escape('(' << creator << ')')       
    end
    mt = []
    params <<  '+AND+('
    if type
      params << 'mediatype:' << type
    else
      @mediatypes.each do |t|
        mt << ('mediatype:' << t)
      end
      params << mt.join('+OR+') 
    end
    params << ')' #closing the mediatypes with a paren
  end
  
  # used on what will be values stuck into a URL as search terms, 
  # does NOT cgi escape, but does safe-ify them in other ways for IA. 
  def safe_argument(string)
    # Downcase params to avoid weird misconfiguration in IA's SOLR
    # installation, where it's interpreting uppercase words as
    # commands even within quotes. 
    output = string.downcase
    
    # Remove parens, semi-colons, brackets, hyphens -- they all mess
    # up IA, which thinks they are special chars. Remove double quote,
    # special char, which sometimes we want to use ourselves. Replace
    # all with spaces to avoid accidentally conjoining words. 
    # (could be
    # escaping instead? Not worth it, we don't want to search
    # on these anyway. Remove ALL punctuation? Not sure.)
    output.gsub!(/[)(\]\[;"\=\-]/, ' ')
    
    return output
  end

  
  def get_results_by_type(results, type)
    results.map{|doc| doc if doc["mediatype"] == type}.compact
  end

  def edition_str(result)
    parts = []
    
    parts.push( result['title']) unless result['title'].blank?
    parts.push( result['publisher'] ) unless result['publisher'].blank?
    parts.push( result['year']) unless result['year'].blank?

    edition_str = parts.join(', ')
    edition_str = nil if edition_str.blank?

    return edition_str
  end

  # catch and redirect response_url fo rsearch_inside
  def response_url(service_type, submitted_params)
    if ( ! (service_type.service_type_value.name == "search_inside" ))
      return super(service_type, submitted_params)
    else
      base = service_type.service_response[:url]
      query = CGI.escape(submitted_params["query"] || "")
      url = base + "#search/#{query}"
      return url
    end
  end
  
  ## collection labels  
  # list of collection labels can be found here:
  # http://www.archive.org/advancedsearch.php?q=mediatype%3Acollection&fl[]=collection&fl[]=identifier&fl[]=title&sort[]=&sort[]=&sort[]=&rows=9999&indent=yes&fmt=json&xmlsearch=Search
  # FIXME either get these dynamically at intervals or add a fuller set below.
  #   Currently there are over 4300 collections.
  # If we're going to do this as a static hash then it should be a class
  # constant. Currently this hash contains a small selection of collections
  # which include the 'audio' mediatype and all that contain the 'texts' mediatype.
  COLLECTION_LABELS = {
    "CaliforniaFishandGame"=>"California Fish and Game",
    "ol_data"=>"Open Library Data",
    "worldhealthorganization"=>"World Health Organization",
    "opensource_movies"=>"Open Source Movies",
    "clairetcarneylibrary"=>
      "Claire T. Carney Library, University of Massachusetts Dartmouth",
    "university_of_illinois_urbana-champaign"=>
      "University of Illinois Urbana-Champaign",
    "smithsonian_books"=>"Smithsonian",
    "nhml_london"=>"Natural History Museum Library, London",
    "animationandcartoons"=>"Animation & Cartoons",
    "university_of_toronto_regis"=>"Regis College Library",
    "vlogs"=>"Vlogs",
    "opensource"=>"Open Source Books",
    "USGovernmentDocuments"=>"US Government Documents",
    "danceman"=>"Dance Manuals",
    "additional_collections"=>"Additional Collections",
    "internet_archive_books"=>"Internet Archive Books",
    "sloan"=>"Sloan Foundation",
    "iacl"=>"Children's Library",
    "audio_religion"=>"Spirituality & Religion",
    "microfilm"=>"Books from Microfilm",
    "toronto"=>"Canadian Libraries",
    "prelinger"=>"Prelinger Archives",
    "bostonpubliclibrary"=>"Boston Public Library",
    "sports"=>"Sports Videos",
    "universallibrary"=>"Universal Library",
    "sfpl"=>"The San Francisco Public Library",
    "university_of_toronto_knox"=>"Caven Library, Knox College",
    "memorial_university"=>"Memorial University of Newfoundland & Labrador",
    "MBLWHOI"=>"MBLWHOI Library",
    "oreilly_books"=>"O'Reilly",
    "burstein"=>"The Burstein Alice in Wonderland Collection",
    "ucroho"=>"Regional Oral History Office",
    "Brandeis_University"=>"Brandeis University Libraries",
    "birney_anti_slavery_collection"=>"Birney Anti-Slavery Collection",
    "Johns_Hopkins_University"=>"The Johns Hopkins University Sheridan Libraries",
    "culturalandacademicfilms"=>"Cultural & Academic Films",
    "Harvard_University"=>"Harvard University",
    "montana_state_publications"=>"Montana State Government Publications",
    "national_institute_for_newman_studies"=>
      "National Institute for Newman Studies",
    "buddha"=>"Buddha Books",
    "university_of_toronto_fisher"=>"Thomas Fisher Rare Book Library",
    "ryerson_university"=>"Ryerson University",
    "university_of_toronto_emmanuel"=>
      "Emmanuel College Library, Victoria University",
    "unica"=>"Unica: Rare Books from UIUC",
    "mugar"=>"The Mugar Memorial Library, Boston University",
    "havergal"=>"Havergal College",
    "university_of_toronto_gerstein"=>
      "University of Toronto - Gerstein Science Information Centre",
    "NY_Botanical_Garden"=>"The New York Botanical Garden",
    "calacademy"=>"California Academy of Sciences",
    "chm_fiche"=>"Computer History Museum",
    "university_of_toronto_crrs"=>
      "Centre for Reformation and Renaissance Studies Library",
    "djo"=>"Dickens Journals Online",
    "unclibraries"=>"University of North Carolina at Chapel Hill",
    "university_of_toronto_oise"=>"OISE/UT Library",
    "newsandpublicaffairs"=>"News & Public Affairs",
    "biodiversity"=>"Biodiversity Heritage Library",
    "university_of_ottawa"=>"University of Ottawa",
    "Wellesley_College_Library"=>"Wellesley College Library",
    "audio_foreign"=>"Non-English Audio",
    "national_library_of_australia"=>"National Library of Australia",
    "datadumps"=>"Open Library Data",
    "microfilmreel"=>"Reels of Microfilm",
    "saint_marys_college"=>"Saint Mary's College of California",
    "university_of_toronto_pratt"=>"E.J. Pratt Library",
    "Boston_College_Library"=>"Boston College Library",
    "uchicago"=>"University of Chicago",
    "audio_podcast"=>"Podcasts",
    "tufts"=>"Tufts University",
    "opensource_audio"=>"Open Source Audio",
    "university_of_toronto_trinity"=>"John W. Graham Library, Trinity College",
    "audio_tech"=>"Computers & Technology",
    "moviesandfilms"=>"Movies",
    "etree"=>"Live Music Archive",
    "marcuslucero"=>"the Marucs Lucero",
    "opencontentalliance"=>"Open Content Alliance",
    "radioprograms"=>"Radio Programs",
    "university_of_toronto_pims"=>"PIMS - University of Toronto",
    "newspapers"=>"Newspapers",
    "university_of_california_libraries"=>"University of California Libraries",
    "millionbooks"=>"Million Book Project",
    "university_of_toronto_robarts"=>"University of Toronto - Robarts Library",
    "university_of_toronto"=>"University of Toronto",
    "montana_state_library"=>"Montana State Library",
    "bancroft_library"=>"The Bancroft Library",
    "prelinger_library"=>"Prelinger Library",
    "libraryofcongress"=>"The Library of Congress",
    "richtest"=>"Test books from California",
    "mobot"=>"Missouri Botanical Garden",
    "gamevideos"=>"Video Games",
    "blc"=>"The Boston Library Consortium",
    "cdl"=>"California Digital Library",
    "Princeton"=>"Princeton Theological Seminary",
    "mcmaster_university"=>"McMaster University",
    "sanfranciscopubliclibrary"=>"San Francisco Public Library",
    "spanish_texts"=>"The Spanish Language Library",
    "boston_college_libraries"=>"The Boston College Libraries",
    "gutenberg"=>"Project Gutenberg",
    "Music_UniversityofToronto"=>"Music - University of Toronto",
    "msn_books"=>"Microsoft",
    "youth_media"=>"Youth Media",
    "independent"=>"independent texts",
    "carletonlibrary"=>"Carleton University Library",
    "arpanet"=>"Arpanet",
    "yahoo_books"=>"Yahoo!",
    "johnadamsBPL"=>"The John Adams Library at the Boston Public Library",
    "library_of_congress"=>"The Library of Congress",
    "ColumbiaUniversityLibraries"=>"Columbia University Libraries",
    "university_of_guelph"=>"University of Guelph",
    "GratefulDead"=>"Grateful Dead",
    "audio_bookspoetry"=>"Audio Books & Poetry",
    "ncsulibraries"=>"North Carolina State University Libraries",
    "brown_university_library"=>"Brown University Library",
    "Allen_County_Public_Library"=>"Allen County Public Library",
    "yrlsc"=>"The Charles E. Young Research Library Special Collections",
    "torontotest"=>"Test books from Canada",
    "americana"=>"American Libraries",
    "librivoxaudio"=>"LibriVox",
    "audio_music"=>"Music & Arts",
    "toronto_public_library"=>"Toronto Public Library",
    "getty"=>"Research Library, Getty Research Institute",
    "ontla"=>"The Legislative Assembly of Ontario Collection",
    "TheChristianRadical"=>"The Christian Radical",
    "netlabels"=>"Netlabels",
    "newyorkpubliclibrary"=>"New York Public Library",
    "University_of_New_Hampshire_Library"=>"University of New Hampshire Library",
    "cbk"=>"Cook Books and Home Economics",
    "audio_news"=>"News & Public Affairs",
    "ant_texts"=>"Ant Texts",
    "computersandtechvideos"=>"Computers & Technology",
    "the_beat_within"=>"The Beat Within Magazine",
    "university_of_toronto_kelly"=>"University of Toronto - John M Kelly Library",
    "library_and_archives_canada"=>"Library and Archives Canada",
    "ephemera"=>"Ephemeral Films",
    "OXFAM"=>"Oxfam",
    "foreignlanguagevideos"=>"Non-English Videos",
    "MontanaStateLibrary"=>"Montana State Library",
    "EarthSciences_UniversityofToronto"=>"Earth Sciences University of Toronto",
    "octavo"=>"Octavo",
    "artsandmusicvideos"=>"Arts & Music"
  }
  

end

# Test URLs using defaults
# Shows texts and audio under fulltext, but only a see also for texts
# http://localhost:3000/resolve?&rft.title=Fairy+Tales&rft.aulast=Andersen&ctx_ver=Z39.88-2004&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook
# 
# Shows texts and audio, but only see also for audio
# http://localhost:3000/resolve?&rft.title=Frankenstein&rft.aulast=Shelley&ctx_ver=Z39.88-2004&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook
#

# WorldCat links
# If you have OpenURL Referrer or another Firefox add-on configured to 
# turn COiNS into an OpenURL to localhost:3000, these links have hits in IA.
# Frankenstein: http://www.worldcat.org/oclc/33045872
# Alice in Wonderland: http://www.worldcat.org/oclc/221499
# Fairy Tales by Andersen: http://www.worldcat.org/oclc/68711386
# Adventures of Huckleberry Finn: http://www.worldcat.org/oclc/2985768
# Gift of the Magi: http://www.worldcat.org/oclc/9065223
# Heart of the West: http://www.worldcat.org/oclc/49293242
# Little Women; or, Meg, Jo, Beth, and Amy: http://www.worldcat.org/oclc/1157 
#   FIXME should we remove everything after ; as well?
# Letters from a Cat: http://www.worldcat.org/oclc/13529549
# Uncle Tom's Cabin: http://www.worldcat.org/oclc/7945691 
#   needed apostrophe to succeed
# Goody Two-Shoes: http://www.worldcat.org/oclc/32678428
# The Snow-Image: http://www.worldcat.org/oclc/5020610
# Les Canadiens-Français: http://www.worldcat.org/oclc/186641188
#   FIXME should match 1 record and doesn't. character encoding problems?
# John L. Stoddard's Lectures: http://www.worldcat.org/oclc/2181690