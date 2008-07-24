# Service that uses available metadata to try to find an exact match to a 
# WorldCat Identity. 
#
# Requires sufficient author information and/or an oclcnumber to have enough
# info to try and find a match. Best to run AFTER services that may enhance
# metadata with this info (such as Amazon). 
# 
# See: http://outgoing.typepad.com/outgoing/2008/06/linking-to-worl.html
# 
# Creates a highlighted_link
# Even though the WorldCat Identities API is built on top of SRU we use 
# open-uri. SRU was too slow and was timing out the background service.
# (because SRU parses the response with REXML? we don't want to have anything
#  to do with REXML! Even still retrieving the large XML file and traversing
#  it with Hpricot is still rather slow. The suggestion is to enable few
#  note_types and then constrain the number shown. The defaults are hopefully 
#  sane in this regard. note_types can be set to false to turn them off.
#  
#  Also can create an optional link to Wikipedia.
#  
#  There's probably a lot more we could pull out of these identities pages if
#  we wanted to. If more of these are used they might warrant their own 
#  service type and part of the page for better layout.

class WorldcatIdentities < Service
  require 'open-uri' # SRU is too slow even though we use an SRU-like link
  require 'hpricot'
  include MetadataHelper
  
  attr_reader :url, :note_types, :display_name, :wikipedia_link, :openurl_base,
    :require_identifier,
    # below starts the note_types which can be restrained
    :num_of_roles, :num_of_subject_headings, :num_of_works, :num_of_genres
  
  def service_types_generated
    return [ ServiceTypeValue[:highlighted_link] ]
  end
  
  def initialize(config)
    @url = 'http://worldcat.org/identities/search/'
    @note_types = ["combined_counts"]
    @display_name = "WorldCat Identities"
    @require_identifier = false
    # any plural note_types can be restrained 
    @num_of_roles = 5
    @num_of_works = 1
    @num_of_genres = 5
    @wikipedia_link = true
    @openurl_widely_held = true
    @worldcat_widely_held = false
    @openurl_base  = '/resolve'
    super(config)
  end
  
  def handle(request)
    index, query = define_query(request.referent)
    
    unless query.blank?
      do_query(request, index, query)
    end
    return request.dispatched(self, true)    
  end
  
  def define_query(rft)
    oclcnum = get_identifier(:info, "oclcnum", rft)
    metadata = rft.metadata
    
    # Do we have enough info to do a query with sufficient precision?
    # We are choosing better recall in exchange for lower precision. 
    # We'll search with oclcnum if we have it, but not require it, we'll search
    # fuzzily on various parts of the name if neccesary.
    if ( oclcnum.blank? && ( metadata['aulast'].blank? || metadata['aufirst'].blank? ) && metadata['au'].blank? && metadata['aucorp'].blank?  ) or (oclcnum.blank? && @require_identifier) 
      RAILS_DEFAULT_LOGGER.debug("Worldcat Identities Service Adaptor: Skipped: Insufficient metadata for lookup")      
      return nil
    end
    
    
    # instead of searching across all indexes we target the one we want
    name_operator = "%3D"
    if ((! metadata['aulast'].blank?) && oclcnum)
      # Just last name is enough, we have an oclcnum.       
      index = 'PersonalIdentities'
      name_part = 'FamilyName'
      name = clean_name(metadata['aulast'])
    elsif (! metadata['au'].blank? )
      # Next choice, undivided author string
      index = "PersonalIdentities"
      name_part = 'Name'
      name = clean_name(metadata['au'])
      name_operator = "all"
    elsif (not metadata['aulast'].blank? and not metadata['aufirst'].blank?)
      # combine them.
      index = "PersonalIdentities"
      name_part = 'Name'
      name = clean_name(metadata['aufirst'] + ' ' + metadata['aulast'])
      name_operator = "all"
    elsif metadata['aucorp']
      # corp name
      index = 'CorporateIdentities'
      name_part = 'Name'
      name = clean_name(metadata['aucorp'])
    else
      # oclcnum but no author information at all! Might still work...
      index = "Identities"
    end

    query_conditions = []
    query_conditions << "local.#{name_part}+#{name_operator}+%22#{name}%22" if name    
    query_conditions << "local.OCLCNumber+%3D+%22#{oclcnum}%22" unless oclcnum.blank?

    query = query_conditions.join("+and+")
    
    # Sort keys is important when we don't have an oclcnumber, and doesn't hurt
    # when we do. 
    query += "&sortKeys=holdingscount"
    return index, query 
  end
  
  # We might have to remove certain characters, but for now we just CGI.escape 
  # it and remove any periods
  def clean_name(name)
    CGI.escape(name).gsub('.', '')
  end
  
  def do_query(request, index, query)
    # since we're only doing exact matching with last name and OCLCnum
    # we only request 1 record to hopefully speed things up.
    link = @url + index + '?query=' +query + "&maximumRecords=1"
    
    result = open(link).read
    xml = Hpricot.XML(result)
    return nil if (xml/"numberOfRecords").inner_text == '0'
    create_link(request, xml)
    create_wikipedia_link(request, xml) if @wikipedia_link
    create_openurl_widely_held(request, xml) if @openurl_widely_held
    create_worldcat_widely_held(request, xml) if @worldcat_widely_held
  end
  
  def create_link(request, xml)
    display_name = "About " + extract_display_name(xml)
    extracted_notes = extract_notes(xml) if @note_types
    url = extract_url(xml)
    create_service_response(request, display_name, url, extracted_notes )
  end
    
  def extract_notes(xml)    
    note_pieces = []    
    # a tiny bit of metaprogramming to make it easy to add methods and config
    # for note_types
    @note_types.each do |nt|
      method = ("extract_" + nt).to_sym  
      answer = self.send(method, xml)
      note_pieces << answer unless answer.nil?
    end
   return nil if note_pieces.blank? 
   return note_pieces.join(' | ')
  end
  
  def extract_display_name(doc)
    name = []    
    rawname = (doc/"nameInfo/rawName")
    return nil unless rawname
    rawname[0].each_child do |name_part|
      name << name_part.inner_text      
    end
    return nil if name.blank?
    return name.join(' ')
  end
    
  def extract_subject_headings(doc)
    subject_headings = []
    (doc/"biogSH").each_with_index do |sh, i|
      subject_headings << sh.inner_text
      break if @num_of_subject_headings == i + 1
    end
    return nil if subject_headings.blank?
    "subject headings: " + subject_headings.join('; ')
  end
  
  def extract_roles(doc)
    codes = []
    (doc/"relators/relator").each_with_index do |relate, i|
      codes << relate.attributes['code']
      break if @num_of_roles == i + 1
    end
    return nil if codes.blank?
    roles = codes.map{|code| RELATOR_CODES[code] }
    "roles: " + roles.join(', ')
  end
  
  # FIXME a lot more could be done with "by citations". identities gives summaries
  # of the most popular works as well as other descriptive information like
  # subject headings. This might be able to be used for enhancing metadata.
  def extract_works(doc)
    works = []
    (doc/"by/citation/title").each_with_index do |t, i|
      works << t.inner_text
      break if @num_of_works == i + 1
    end
    return nil if works.blank?
    "most widely held #{works.length == 1 ? "work" : "works"}: " + works.join("; ")
  end
  
  def extract_genres(doc)
    genres = []
    (doc/"genres/genre").each_with_index do |g, i|
      genres << g.inner_text
      break if @num_of_genres == i + 1
    end
    return nil if genres.blank?
    "genres: " + genres.join(', ')
  end
  
  def extract_combined_counts(doc)
    work_count = extract_work_count(doc)
    publications_count = extract_publications_count(doc)
    holdings_count = extract_holdings_count(doc)
    work_count << " in " << publications_count << " with " <<
      holdings_count
  end
  
  def extract_work_count(doc)
    work_count = (doc/"workCount").inner_html
    return insert_commas(work_count)  << " works"
  end
  
  def extract_holdings_count(doc)
    total_holdings = (doc/"totalHoldings").inner_html
    return insert_commas(total_holdings) << " total holdings in WorldCat"
  end
  
  def extract_publications_count(doc)
    return insert_commas( (doc/"recordCount").inner_html ) << " publications"
  end
  
  def extract_url(doc)
    pnkey = (doc/"pnkey").inner_text
    return 'http://worldcat.org/identities/' << pnkey
  end
  
  def insert_commas(n)
    n.reverse.scan(/(?:\d*\.)?\d{1,3}-?/).join(',').reverse
  end
  
  def create_service_response(request, display_name, url, extracted_notes)
    request.add_service_response( { 
        :service=>self,    
        :url=>url,
        :display_text=>display_name,
        :service_data => {:notes => extracted_notes}},
      [ServiceTypeValue[:highlighted_link]]    )
  end
  
  def create_wikipedia_link(request, xml)
    name_element =  (xml/"wikiLink")
    return nil if name_element.empty?
    name = name_element.inner_text
    # This is the base link that worldcat identities uses so we use the same
    link = "http://en.wikipedia.org/wiki/Special:Search?search=" << name
    request.add_service_response( { 
        :service=>self,    
        :url=>link,
        :display_text=> "About " + name.titlecase,
        :service_data => {:notes => '', :source => 'Wikipedia' }},
      [ServiceTypeValue[:highlighted_link]]    )
  end
  
  def create_openurl_widely_held(request, xml)
    widely_held = get_widely_held_info(xml)
    # try to remove circular links
    return nil if circular_link?(request, widely_held)
    
    openurl = create_openurl(request, widely_held) 
    
    request.add_service_response( { 
        :service=>self,    
        :url=>openurl,
        :display_text=> widely_held['title'],
        :service_data => {:notes => "Find It: This author's most widely held work." }},
      [ServiceTypeValue[:highlighted_link]] ) 
  end
  
  def circular_link?(request, citation_info)
    rft = request.referent
    request_oclcnum = get_identifier(:info, "oclcnum", rft)
    request_title = get_search_title(rft)
    return true if citation_info['oclcnum'] == request_oclcnum
    #further cleaning might be necessary for titles to be good matches
    return true if citation_info['title'].strip == request_title.strip
  end
  
  #createsa  minimal openurl to make a new request to umlaut
  def create_openurl(request, wh)
    metadata = request.referent.metadata
    
    co = OpenURL::ContextObject.new
    cor = co.referent
    cor.set_format(wh['record_type'])
    cor.add_identifier("info:oclcnum/#{wh['oclcnum']}")
    cor.set_metadata('aulast', metadata['aulast'] ) if metadata['aulast']
    cor.set_metadata('aufirst', metadata['aufirst']) if metadata['aufirst']
    cor.set_metadata('aucorp', metadata['aucorp']) if metadata['aucorp']
    cor.set_metadata('title', wh['title'])
    link = @openurl_base + '?' + co.kev
    return link
  end
  
  # We just link to worldcat using the oclc number provided
  # FIXME this might need special partial if we incorporate a cover image
  def create_worldcat_widely_held(request, xml)
    
    # try to prevent circular links
    top_holding_info = get_widely_held_info(xml) 
    return nil if circular_link?(request, top_holding_info)    
    
    # http://www.worldcat.org/links/
    most = top_holding_info['most']
    title = top_holding_info['title']
    oclcnum = top_holding_info['oclcnum']
    
    link = 'http://www.worldcat.org/oclc/' << oclcnum
    cover_image_link = extract_cover_image_link(request, most)    
    notes = "this author's most widely held work in WorldCat"
     if  cover_image_link 
      display_text = '<img src="' << cover_image_link << '" style="width:75px;"/>' 
      notes = title << ' is ' << notes
    else
      display_text = title
    end
    
    request.add_service_response( { 
        :service=>self,    
        :url=>link,
        :display_text=> display_text,
        :service_data => {:notes => notes}},
      [ServiceTypeValue[:highlighted_link]] ) 
  end
  
  def get_widely_held_info(xml)
    h = {}
    h['most'] = most = (xml/"by/citation")[0]
    h['oclcnum'] = clean_oclcnum((most/"oclcnum").inner_text)
    h['title'] = (most/"title").inner_text
    h['record_type'] = (most/'recordType').inner_text
    h
  end
  
  def extract_cover_image_link(request, citation)
    cover = (citation/"cover")[0]
    return nil unless cover
    # we try not to show a cover if we already probably have the same cover 
    # showing.
    oclc = clean_oclcnum( cover.attributes['oclc'] )
    metadata = request.referent.metadata
    if metadata['oclcnum'] and metadata['oclcnum'] =~ oclc
      return nil
    end 
    cover_number = cover.inner_text
    if metadata['isbn'] and metadata['isbn'] == cover_number
      return nil
    end
    
    if cover.attributes["type"] == 'isbn'
      link = "http://www.worldcat.org/wcpa/servlet/DCARead?standardNoType=1&standardNo="
      return link << cover_number
    end
    return nil
  end
  
  def clean_oclcnum(num)
    # got the follow from referent.rb ~152 and added ocn
    if num =~ /(ocn0*|ocm0*|\(OCoLC\)|ocl70*)(.*)$/
      num = $2
    end
    return num
  end
  
  # relator codes are from http://worldcat.org/identities/relators.xml which was
  # referenced from http://worldcat.org/identities/Identities.xsl
  RELATOR_CODES = {
    "act" => "Actor",
    "adp" => "Adapter",
    "aft" => "Author of afterword, colophon, etc.",
    "anm" => "Animator ",
    "ann" => "Annotator",
    "ant" => "Bibliographic antecedent",
    "app" => "Applicant",
    "aqt" => "Author in quotations or text abstracts",
    "arc" => "Architect",
    "arr" => "Arranger",
    "art" => "Artist",
    "asg" => "Assignee",
    "asn" => "Associated name",
    "att" => "Attributed name",
    "auc" => "Auctioneer",
    "aud" => "Author of dialog",
    "aui" => "Author of introduction",
    "aus" => "Author of screenplay",
    "aut" => "Author",
    "bdd" => "Binding designer",
    "bjd" => "Bookjacket designer",
    "bkd" => "Book designer",
    "bkp" => "Book producer",
    "bnd" => "Binder",
    "bpd" => "Bookplate designer",
    "bsl" => "Bookseller",
    "ccp" => "Conceptor",
    "chr" => "Choreographer",
    "clb" => "Collaborator",
    "cli" => "Client",
    "cll" => "Calligrapher",
    "clt" => "Collotyper",
    "cmm" => "Commentator",
    "cmp" => "Composer",
    "cmt" => "Compositor",
    "cng" => "Cinematographer ",
    "cnd" => "Conductor",
    "cns" => "Censor",
    "coe" => "Contestant -appellee",
    "col" => "Collector",
    "com" => "Compiler",
    "cos" => "Contestant",
    "cot" => "Contestant -appellant",
    "cov" => "Cover designer",
    "cpc" => "Copyright claimant",
    "cpe" => "Complainant-appellee",
    "cph" => "Copyright holder",
    "cpl" => "Complainant",
    "cpt" => "Complainant-appellant",
    "cre" => "Creator",
    "crp" => "Correspondent",
    "crr" => "Corrector",
    "csl" => "Consultant",
    "csp" => "Consultant to a project",
    "cst" => "Costume designer",
    "ctb" => "Contributor",
    "cte" => "Contestee-appellee",
    "ctg" => "Cartographer",
    "ctr" => "Contractor",
    "cts" => "Contestee",
    "ctt" => "Contestee-appellant",
    "cur" => "Curator",
    "cwt" => "Commentator for written text",
    "dfd" => "Defendant",
    "dfe" => "Defendant-appellee",
    "dft" => "Defendant-appellant",
    "dgg" => "Degree grantor",
    "dis" => "Dissertant",
    "dln" => "Delineator",
    "dnc" => "Dancer",
    "dnr" => "Donor",
    "dpc" => "Depicted",
    "dpt" => "Depositor",
    "drm" => "Draftsman",
    "drt" => "Director",
    "dsr" => "Designer",
    "dst" => "Distributor",
    "dte" => "Dedicatee",
    "dto" => "Dedicator",
    "dub" => "Dubious author",
    "edt" => "Editor",
    "egr" => "Engraver",
    "elt" => "Electrotyper",
    "eng" => "Engineer",
    "etr" => "Etcher",
    "exp" => "Expert",
    "fac" => "Facsimilist",
    "flm" => "Film editor",
    "fmo" => "Former owner",
    "fpy" => "First party",
    "fnd" => "Funder",
    "frg" => "Forger",
    "grt" => "Graphic technician",
    "hnr" => "Honoree",
    "hst" => "Host",
    "ill" => "Illustrator",
    "ilu" => "Illuminator",
    "ins" => "Inscriber",
    "inv" => "Inventor",
    "itr" => "Instrumentalist",
    "ive" => "Interviewee",
    "ivr" => "Interviewer",
    "lbt" => "Librettist",
    "lee" => "Libelee-appellee",
    "lel" => "Libelee",
    "len" => "Lender",
    "let" => "Libelee-appellant",
    "lgd" => "Lighting designer ",
    "lie" => "Libelant-appellee",
    "lil" => "Libelant",
    "lit" => "Libelant-appellant",
    "lsa" => "Landscape architect",
    "lse" => "Licensee",
    "lso" => "Licensor",
    "ltg" => "Lithographer",
    "lyr" => "Lyricist",
    "mfr" => "Manufacturer ",
    "mdc" => "Metadata contact",
    "mod" => "Moderator",
    "mon" => "Monitor",
    "mrk" => "Markup editor",
    "mte" => "Metal-engraver",
    "mus" => "Musician",
    "nrt" => "Narrator",
    "opn" => "Opponent",
    "org" => "Originator",
    "orm" => "Organizer of meeting",
    "oth" => "Other",
    "own" => "Owner",
    "pat" => "Patron",
    "pbd" => "Publishing director",
    "pbl" => "Publisher",
    "pfr" => "Proofreader",
    "pht" => "Photographer",
    "plt" => "Platemaker",
    "pop" => "Printer of plates",
    "ppm" => "Papermaker",
    "ppt" => "Puppeteer ",
    "prc" => "Process contact",
    "prd" => "Production personnel",
    "prf" => "Performer",
    "prg" => "Programmer",
    "prm" => "Printmaker",
    "pro" => "Producer",
    "prt" => "Printer",
    "pta" => "Patent applicant",
    "pte" => "Plaintiff -appellee",
    "ptf" => "Plaintiff",
    "pth" => "Patent holder",
    "ptt" => "Plaintiff-appellant",
    "rbr" => "Rubricator",
    "rce" => "Recording engineer",
    "rcp" => "Recipient",
    "red" => "Redactor",
    "ren" => "Renderer",
    "res" => "Researcher",
    "rev" => "Reviewer",
    "rpt" => "Reporter",
    "rpy" => "Responsible party",
    "rse" => "Respondent -appellee",
    "rsg" => "Restager ",
    "rsp" => "Respondent",
    "rst" => "Respondent-appellant",
    "rth" => "Research team head",
    "rtm" => "Research team member",
    "sad" => "Scientific advisor",
    "sce" => "Scenarist",
    "scl" => "Sculptor",
    "scr" => "Scribe",
    "sec" => "Secretary",
    "sgn" => "Signer",
    "sng" => "Singer",
    "spk" => "Speaker",
    "spn" => "Sponsor",
    "spy" => "Second party",
    "srv" => "Surveyor",
    "std" => "Set designer ",
    "stl" => "Storyteller",
    "stn" => "Standards body",
    "str" => "Stereotyper",
    "tch" => "Teacher ",
    "ths" => "Thesis advisor",
    "trc" => "Transcriber",
    "trl" => "Translator",
    "tyd" => "Type designer",
    "tyg" => "Typographer",
    "vdg" => "Videographer ",
    "voc" => "Vocalist",
    "wam" => "Writer of accompanying material",
    "wdc" => "Woodcutter",
    "wde" => "Wood -engraver",
    "wit" => "Witness"    
  }
  
end