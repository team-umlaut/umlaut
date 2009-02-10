include Exlibris::PrimoWS
module Exlibris::Primo
  # Use web services for better performance
  class Searcher
    ISBN_Index = "isbn"
    ISSN_Index = "isbn"
    Title_Index = "title"
    Author_Index = "creator"

    attr_accessor :base_url, :config, :base_view_id
    attr_accessor :referrer, :primo_id
    attr_accessor :issn, :isbn
    attr_accessor :title, :author, :genre
    attr_accessor :response, :error
    attr_reader :count, :holdings, :urls
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
      if primo_id.nil?
        # Primo ISSN Query Term
        issn_qt = QueryTerm.new(issn, ISSN_Index) unless issn.nil?
        qts = Exlibris::PrimoWS::QueryTerms.new(issn_qt) unless issn_qt.nil?

        # Primo ISBN Query Term
        isbn_qt = QueryTerm.new(isbn, ISBN_Index) unless isbn.nil?
        qts = Exlibris::PrimoWS::QueryTerms.new(isbn_qt) unless isbn_qt.nil?

        #TODO: Use Title/Author/Genre search if no ISN
        if issn.nil? and isbn.nil?
          #TODO: Limit by genre
          title_qt = QueryTerm.new(title, Title_Index, "exact") unless title.nil?
          qts = Exlibris::PrimoWS::QueryTerms.new(title_qt) unless title_qt.nil?
          author_qt = QueryTerm.new(title, Author_Index, "exact") unless title.nil? or author.nil?
          qts.add_query_term(author_qt) unless author_qt.nil?
        end
      end
      psr = PrimoSearchRequest.new(qts) unless qts.nil?
    end

    def count
      return @count unless @count.nil?
      search if response.nil?
      e = response.elements["//DOCSET"]
      a = e.attribute("TOTALHITS", "http://www.exlibrisgroup.com/xsd/jaguar/search") unless e.nil?
      @count = a.value unless a.nil?
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
      response.each_element("//record") do |rec|
        record_id = nil
        original_source_id = nil
        source_id = nil
        source_record_id = nil
        # Just take last element for record level elements 
        # (should only be one, except may sourceid which will be handled later)
        rec.each_element("control/recordid") { |e| record_id = e.text }
        rec.each_element("control/originalsourceid") { |e| original_source_id = e.text }
        original_source_ids = control_hash(rec, "control/originalsourceid")
        rec.each_element("control/sourceid") { |e| source_id = e.text }
        source_ids = control_hash(rec, "control/sourceid")
        rec.each_element("control/sourcerecordid") { |e| source_record_id = e.text }
        source_record_ids = control_hash(rec, "control/sourcerecordid")
        rec.each_element("display/availlibrary") do |e|
          # Get holdings based on display/availlibrary
          holding = Holding.new(e)
          holding.primo_base_url = base_url
          holding.primo_view_id = base_view_id
          holding.primo_config = config
          holding.record_id = record_id
          holding_original_source_id = (holding.origin.nil? ? original_source_ids[record_id] : original_source_ids[holding.origin]) unless original_source_ids.empty?
          holding.original_source_id = (holding_original_source_id.nil? ? original_source_id : holding_original_source_id)
          holding_source_id = (holding.origin.nil? ? source_ids[record_id] : source_ids[holding.origin]) unless source_ids.empty?
          holding.source_id = (holding_source_id.nil? ? source_id : holding_source_id)
          holding_source_record_id = (holding.origin.nil? ? source_record_ids[record_id] : source_record_ids[holding.origin]) unless source_record_ids.empty?
          holding.source_record_id = (holding_source_record_id.nil? ? source_record_id : holding_source_record_id)
          holding.source_config = sources_config[holding.source_id] unless sources_config.nil?
          holding = holding.to_source if goto_source? 
          @holdings.push(holding) unless holding.nil?
        end
      end
      return holdings
    end
 
    def control_hash (record, xpath)
      h = {}
      record.each_element(xpath) do |e|
        str = e.text unless e.nil?
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
      response.each_element("//record") do |rec|
        record_id = nil
        # Just take last element for record id elements, there should only be one
        rec.each_element("control/recordid") { |e| record_id = e.text }
        rec.each_element("links/linktorsrc") do |e|
          # Get holdings based on links/linktorsrc
          url = Url.new(e) unless e.nil?
          url.record_id = record_id unless record_id.nil?
          @urls.push(url) unless url.nil?
        end
      end
      return urls
    end

    # Execute search based on instance vars
    def search
      return [] if insufficient_query
      ws = nil
      # Call Primo Web Services
      if primo_id
        ws = GetRecord.new(primo_id, base_url)
      else
        ws = SearchBrief.new(search_request, base_url)
      end
      @response = ws.response unless ws.nil?
      @error = ws.error unless ws.nil?
      return holdings
    end

    def insufficient_query
      # Have to have some search criteria to search
      # TODO: Include title/author/genre search
      #return (self.primo_id.nil? && self.issn.nil? && self.isbn.nil? && (self.title.nil? or self.author.nil? or self.genre.nil? )
      return (self.primo_id.nil? && self.issn.nil? && self.isbn.nil?)
    end
    
    private
    def goto_source?
      @goto_source.to_i == 1 or primo_referrer?
    end

    def primo_referrer?
      return false if referrer.nil?
      return (referrer.match('info:sid/primo.exlibrisgroup.com').nil? ? false : true)
    end
  end
end