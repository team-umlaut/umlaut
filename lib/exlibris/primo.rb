include Exlibris::PrimoWS
module Exlibris::Primo
  # Use web services for better performance
  class PrimoSearcher
    ISBN_Index = "isbn"
    ISSN_Index = "isbn"
    Title_Index = "title"
    Author_Index = "creator"

    attr_accessor :base_url_str, :base_view_id
    attr_accessor :primo_id
    attr_accessor :issn, :isbn
    attr_accessor :title, :author, :genre
    attr_accessor :response, :error
    attr_reader :count, :holdings, :urls
    def initialize(base_url_str, base_view_id)
      @base_url_str = base_url_str
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
      # Loop through records and to get ids and sources
      response.each_element("//record") do |rec|
        record_id = nil
        source_system = nil
        source_id = nil
        # Just take last element for record level elements 
        # (should only be one, except may sourceid which will be handled later)
        rec.each_element("control/recordid") { |e| record_id = e.text }
        rec.each_element("control/sourcesystem") { |e| source_system = e.text }
        rec.each_element("control/sourceid") { |e| source_id = e.text }
        rec.each_element("display/availlibrary") do |e|
          # Get holdings based on display/availlibrary
          holding = PrimoHolding.new(e) unless e.nil?
          holding.base_url_str = base_url_str
          holding.base_view_id = base_view_id
          holding.record_id = record_id unless record_id.nil?
          holding.source_system = source_system unless source_system.nil?
          holding.source_id = source_id unless source_id.nil?
          @holdings.push(holding) unless holding.nil?
        end
      end
      return holdings
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
        source_system = nil
        source_id = nil
        # Just take last element for record level elements 
        # (should only be one, except may sourceid which will be handled later)
        rec.each_element("control/recordid") { |e| record_id = e.text }
        rec.each_element("control/sourcesystem") { |e| source_system = e.text }
        rec.each_element("control/sourceid") { |e| source_id = e.text }
        rec.each_element("links/linktorsrc") do |e|
          # Get holdings based on links/linktorsrc
          url = PrimoURL.new(e) unless e.nil?
          url.record_id = record_id unless record_id.nil?
          url.source_system = source_system unless source_system.nil?
          url.source_id = source_id unless source_id.nil?
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
        ws = GetRecord.new(primo_id, base_url_str)
      else
        ws = SearchBrief.new(search_request, base_url_str)
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
  end
  
  # Class for handling Primo URLs from links/linktorsrc
  # TODO: Should probably extend a base class of some sort
  class PrimoURL
    attr_accessor :base_url_str
    attr_accessor :record_id, :source_system, :source_id
    attr_accessor :institution, :url, :display, :origin
    attr_accessor :notes, :text
    def initialize(e)
      @text = e.text unless e.nil?
      a = @text.split(/\$(?=\$)/) unless @text.nil?
      a.shift unless (a.nil? or a.empty?)
      v = (!((a.nil? or a.empty?) or a.first.match(/^\$V/).nil?) ? a.shift.sub!(/^\$V/, "") : "")
      @url = (!((a.nil? or a.empty?) or a.first.match(/^\$U/).nil?) ? a.shift.sub!(/^\$U/, "") : "")
      @display = (!((a.nil? or a.empty?) or a.first.match(/^\$D/).nil?) ? a.shift.sub!(/^\$D/, "") : nil)
      @institution = (!((a.nil? or a.empty?) or a.first.match(/^\$I/).nil?) ? a.shift.sub!(/^\$I/, "") : "")
      @origin = (!((a.nil? or a.empty?) or a.first.match(/^\$O/).nil?) ? a.shift.sub!(/^\$O/, "") : "")
    end
  end

  # Class for handling Primo Holdings from display/availlibrary
  # TODO: Should probably extend a base class of some sort
  class PrimoHolding
    attr_accessor :base_url_str, :base_view_id
    attr_accessor :record_id, :source_system, :source_id
    attr_accessor :institution, :library, :id_one, :id_two, :status, :origin
    attr_accessor :collection_str, :call_number
    attr_accessor :notes, :text, :raw
    attr_reader :url_id, :url
    def initialize(e)
      @raw = e.text unless e.nil?
      # TODO: Further investigation, not sure what purpose text serves.
      @text = @raw
      a = @raw.split(/\$(?=\$)/) unless @raw.nil?
      a.shift unless (a.nil? or a.empty?)
      @institution = (!((a.nil? or a.empty?) or a.first.match(/^\$I/).nil?) ? a.shift.sub!(/^\$I/, "") : "")
      @library = (!((a.nil? or a.empty?) or a.first.match(/^\$L/).nil?) ? a.shift.sub!(/^\$L/, "") : "")
      @id_one = (!((a.nil? or a.empty?) or a.first.match(/^\$1/).nil?) ? a.shift.sub!(/^\$1/, "") : "")
      @id_two = (!((a.nil? or a.empty?) or a.first.match(/^\$2/).nil?) ? a.shift.sub!(/^\$2/, "") : "")
      @status = (!((a.nil? or a.empty?) or a.first.match(/^\$S/).nil?) ? a.shift.sub!(/^\$S/, "") : "")
      @origin = (!((a.nil? or a.empty?) or a.first.match(/^\$O/).nil?) ? a.shift.sub!(/^\$O/, "") : nil)
      @call_number = id_two
    end
    
    def url_id
      return @url_id unless @url_id.nil?
      # Pass back record_id or origin id
      # TODO: Need to further discuss optimal functionality
      #@url_id = (origin.nil? ? record_id : origin)
      @url_id = record_id
      url_id
    end

    def url
      # TODO: Primo URLs a should probably point to source record.
      #       Currently just pointing back to Primo.
      #       Could be based on referrer id, if Primo -> source, otherwise -> Primo.
      #       Further discussion required
      return url = base_url_str + "/primo_library/libweb/action/dlDisplay.do?docId=" + url_id + "&institution=" + institution + "&vid=" + base_view_id + "&reset_config=true"
    end
  end
end
    
