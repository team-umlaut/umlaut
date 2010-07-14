include Exlibris::PrimoWS
module Exlibris::Primo
  # Use web services for better performance
  class Searcher
    ISBN_Index = "isbn"
    ISSN_Index = "isbn"
    Title_Index = "title"
    Author_Index = "creator"
    Any_Index = "any"

    attr_accessor :base_url, :config, :base_view_id
    attr_accessor :referrer, :primo_id
    attr_accessor :issn, :isbn
    attr_accessor :title, :author, :genre
    attr_accessor :response, :error
    attr_reader :count, :holdings, :urls
    attr_reader :titles, :authors
    attr_reader :au, :aulast, :aufirst, :aucorp
    attr_reader :pub, :place
    attr_reader :oclcid, :lccn
    attr_reader :btitle, :jtitle
    attr_reader :cover_image
    attr_reader :goto_source
    
    def initialize(base_url, config, goto_source, base_view_id)
      @base_url = base_url
      @config = config
      @goto_source = goto_source
      @base_view_id = base_view_id
    end

    def search_request
      return nil if insufficient_query
      # Primo Id doesn't require Query Term to be specified, empty QueryTerms element is sufficient.
      qts = Exlibris::PrimoWS::QueryTerms.new()
      if primo_id.nil? or primo_id.empty?
        # Primo ISSN Query Term
        issn_qt = QueryTerm.new(issn, ISSN_Index) unless issn.nil? or issn.empty?
        qts = Exlibris::PrimoWS::QueryTerms.new(issn_qt) unless issn_qt.nil?

        # Primo ISBN Query Term
        isbn_qt = QueryTerm.new(isbn, ISBN_Index) unless isbn.nil? or isbn.empty?
        qts = Exlibris::PrimoWS::QueryTerms.new(isbn_qt) unless isbn_qt.nil?

        #TODO: Use Title/Author/Genre search if no ISN
        if (issn.nil? or issn.empty?) and (isbn.nil? or isbn.empty?)
          #TODO: Limit by genre
          title_qt = QueryTerm.new(title, Title_Index, "begins_with") unless title.nil?
          qts = Exlibris::PrimoWS::QueryTerms.new(title_qt) unless title_qt.nil?
          author_qt = QueryTerm.new(author, Author_Index, "exact") unless title.nil? or author.nil?
          qts.add_query_term(author_qt) unless author_qt.nil?
          genre_qt = QueryTerm.new(genre, Any_Index, "exact") unless title.nil? or author.nil? or genre.nil?
          qts.add_query_term(genre_qt) unless genre_qt.nil?
        end
      end
      psr = PrimoSearchRequest.new(qts) unless qts.nil?
    end

    def count
      return @count unless @count.nil?
      search if response.nil?
      a = 0
      response.search("//DOCSET").each { |e| a = e.attributes["TOTALHITS"] unless e.nil? }
      @count = a
      return count
    end

    # Returns holdings array
    def holdings
      return @holdings if @holdings.kind_of? Array
      search if response.nil?
      @holdings = []
      return @holdings if response.nil?
      sources_config = config["sources"] unless config.nil?
      # Loop through records and to get ids and sources
      #response.each_element("//record") do |rec|
      response.search("//record") do |rec|
        rec_genre = (rec.at("addata/genre").nil?) ? "article" : rec.at("addata/genre").inner_text
        #Check for genre
        next unless (genre == rec_genre or (genre == "journal" and rec_genre == "article"))
        holdings_seen = Array.new # for de-duplicating holdings from a given source.  Needed for Primo/Aleph single location bug.
        # Just take the first element for record level elements 
        # (should only be one, except may sourceid which will be handled later)
        record_id = rec.at("control/recordid").inner_text unless rec.at("control/recordid").nil?
        display_type = rec.at("display/type").inner_text unless rec.at("display/type").nil?
        original_source_id = rec.at("control/originalsourceid").inner_text unless rec.at("control/originalsourceid").nil?
        original_source_ids = control_hash(rec, "control/originalsourceid")
        source_id = rec.at("control/sourceid").inner_text unless rec.at("control/sourceid").nil?
        source_ids = control_hash(rec, "control/sourceid")
        source_record_id = rec.at("control/sourcerecordid").inner_text unless rec.at("control/sourcerecordid").nil?
        source_record_ids = control_hash(rec, "control/sourcerecordid")
        rec.search("display/availlibrary") do |e|
          # Get holdings based on display/availlibrary
          holding = Holding.new(e)
          holding.match_reliability = (reliable_match?(rec)) ? ServiceResponse::MatchExact : ServiceResponse::MatchUnsure
          holding.primo_base_url = base_url
          holding.primo_view_id = base_view_id
          holding.primo_config = config
          holding.record_id = record_id
          holding.display_type = display_type
          holding_original_source_id = (holding.origin.nil? ? original_source_ids[record_id] : original_source_ids[holding.origin]) unless original_source_ids.empty?
          holding.original_source_id = (holding_original_source_id.nil? ? original_source_id : holding_original_source_id)
          holding_source_id = (holding.origin.nil? ? source_ids[record_id] : source_ids[holding.origin]) unless source_ids.empty?
          holding.source_id = (holding_source_id.nil? ? source_id : holding_source_id)
          holding_source_record_id = (holding.origin.nil? ? source_record_ids[record_id] : source_record_ids[holding.origin]) unless source_record_ids.empty?
          holding.source_record_id = (holding_source_record_id.nil? ? source_record_id : holding_source_record_id)
          holding.source_config = sources_config[holding.source_id] unless sources_config.nil?
          
          # Some sources may be mapping several source holdings to one primo holding
          # We want to display all source holdings.
          holding = holding.to_source if goto_source
          # There are some cases where source records may need to be deduplicated against existing records
          # Check if we've already seen this record.
          seen_holdings_key = holding.source_id.to_s+ holding.source_record_id.to_s
          next if holding.dedup? and holdings_seen.include?(seen_holdings_key)
          # If we get this far, record that we've seen this holding.
          holdings_seen.push(seen_holdings_key)

          holding.to_a.each do |h|
            @holdings.push(h) unless h.nil? or h.library.nil?
          end
#=end
        end
      end
      return holdings
    end
    
    def btitle
      return @btitle unless @btitle.nil?
      search if response.nil?
      @btitle = ""
      @btitle = response.at("//addata/btitle").inner_text.chars.to_s unless response.nil? or response.at("//addata/btitle").nil?
      return btitle
    end
 
    def jtitle
      return @jtitle unless @jtitle.nil?
      search if response.nil?
      @jtitle = ""
      @jtitle = response.at("//addata/jtitle").inner_text.chars.to_s unless response.nil? or response.at("//addata/jtitle").nil?
      return jtitle
    end
 
    def titles
      return @titles if @titles.kind_of? Array
      search if response.nil?
      @titles = []
      return @titles if response.nil?
      # Loop through display/titles
      response.search("//display/title") do |e|
        @titles.push(e.inner_text.chars.to_s)
      end
      return titles
    end
 
    def au
      return @au unless @au.nil?
      search if response.nil?
      @au = ""
      @au = response.at("//addata/au").inner_text.chars.to_s unless response.nil? or response.at("//addata/au").nil?
      return au
    end
 
    def aulast
      return @aulast unless @aulast.nil?
      search if response.nil?
      @aulast = ""
      @aulast = response.at("//addata/aulast").inner_text.chars.to_s unless response.nil? or response.at("//addata/aulast").nil?
      return aulast
    end
 
    def aufirst
      return @aufirst unless @aufirst.nil?
      search if response.nil?
      @aufirst = ""
      @aufirst = response.at("//addata/aufirst").inner_text.chars.to_s unless response.nil? or response.at("//addata/aufirst").nil?
      return aufirst
    end
 
    def aucorp
      return @aucorp unless @aucorp.nil?
      search if response.nil?
      @aucorp = ""
      @aucorp = response.at("//addata/aucorp").inner_text.chars.to_s unless response.nil? or response.at("//addata/aucorp").nil?
      return aucorp
    end
 
    def authors
      return @authors if @authors.kind_of? Array
      search if response.nil?
      @authors = []
      return @authors if response.nil?
      # Loop through rdisplay/creator
      response.search("//display/creator") do |e|
        @authors.push(e.inner_text.chars.to_s)
      end
      return authors
    end
 
    def pub
      return @pub unless @pub.nil?
      search if response.nil?
      @pub = ""
      @pub = response.at("//addata/pub").inner_text.chars.to_s unless response.nil? or response.at("//addata/pub").nil?
      return pub
    end
 
    def place
      return @place unless @place.nil?
      search if response.nil?
      @place = ""
      @place = response.at("//addata/cop").inner_text.chars.to_s unless response.nil? or response.at("//addata/cop").nil?
      return place
    end
 
    def cover_image
      return @cover_image unless @cover_image.nil?
      search if response.nil?
      @cover_image = ""
      @cover_image = response.at("//addata/lad02").inner_text unless response.nil? or response.at("//addata/lad02").nil?
      return cover_image
    end
 
    def oclcid
      return @oclcid unless @oclcid.nil?
      search if response.nil?
      @oclcid = ""
      @oclcid = response.at("//addata/oclcid").inner_text.chars.to_s unless response.nil? or response.at("//addata/oclcid").nil?
      return oclcid
    end
 
    def lccn
      return @lccn unless @lccn.nil?
      search if response.nil?
      @lccn = ""
      @lccn = response.at("//addata/lccn").inner_text.chars.to_s unless response.nil? or response.at("//addata/lccn").nil?
      return lccn
    end
 
    def control_hash (record, xpath)
      h = {}
      record.search(xpath) do |e|
        str = e.inner_text unless e.nil?
        a = str.split(/\$(?=\$)/) unless str.nil?
        v = nil
        o = nil
        a.each do |s|
          v = s.sub!(/^\$V/, "") unless s.match(/^\$V/).nil?
          o = s.sub!(/^\$O/, "") unless s.match(/^\$O/).nil?
        end
        h[o] = v unless (o.nil? or v.nil?)
      end
      return h
    end
    
    # Returns urls array
    def urls
      return @urls if @urls.kind_of? Array
      search if response.nil?
      @urls = []
      return @urls if response.nil?
      # Loop through records and to get ids and sources
      response.search("//record") do |rec|
        # Just take first element for record id elements, there should only be one
        record_id = rec.at("control/recordid").inner_text
        rec.search("links/linktorsrc") do |e|
          # Get urls based on links/linktorsrc
          url = Url.new(e) unless e.nil?
          url.record_id = record_id unless record_id.nil?
          @urls.push(url) unless url.nil?
        end
      end
      return urls
    end

    # Returns tocs array
    def tocs
      return @tocs if @tocs.kind_of? Array
      search if response.nil?
      @tocs = []
      return @tocs if response.nil?
      # Loop through records and to get ids and sources
      response.search("//record") do |rec|
        # Just take last element for record id elements, there should only be one
        record_id = rec.at("control/recordid").inner_text
        rec.search("links/linktotoc") do |e|
          # Get tocs based on links/linktotoc
          toc = Toc.new(e) unless e.nil?
          toc.record_id = record_id unless record_id.nil?
          @tocs.push(toc) unless (toc.nil? or toc.url.nil?)
        end
      end
      return tocs
    end

    # Execute search based on instance vars
    def search
      return [] if insufficient_query
      ws = nil
      # Call Primo Web Services
      unless primo_id.nil? or primo_id.empty?
        ws = GetRecord.new(primo_id, base_url)
      else
        ws = SearchBrief.new(search_request, base_url)
      end
      @response = ws.response unless ws.nil?
      @error = ws.error unless ws.nil?
    end

    def insufficient_query
      # Have to have some search criteria to search
      # TODO: Include title/author/genre search
      #return (self.primo_id.nil? && self.issn.nil? && self.isbn.nil? && (self.title.nil? or self.author.nil? or self.genre.nil?))
      return ((self.primo_id.nil? or self.primo_id.empty?) && (self.issn.nil? or self.issn.empty?) && (self.isbn.nil? or self.isbn.empty?) && ((self.title.nil? or self.title.empty?) or (self.author.nil? or self.author.empty?) or (self.genre.nil? or self.genre.empty?)))
      #return (self.primo_id.nil? && self.issn.nil? && self.isbn.nil?)
    end
    
    private
    def goto_source?
      @goto_source or primo_referrer?
    end

    def primo_referrer?
      return false if referrer.nil?
      return (referrer.match('info:sid/primo.exlibrisgroup.com').nil? ? false : true)
    end
    
    def reliable_match?(rec)
      return true unless ((self.primo_id.nil? or self.primo_id.empty?) && (self.issn.nil? or self.issn.empty?) && (self.isbn.nil? or self.isbn.empty?) && (rec.at("display/title").inner_text != title))
    end
  end
end