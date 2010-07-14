module Exlibris::Primo
  # Class for handling Primo Holdings from display/availlibrary
  # TODO: Should probably extend a base class of some sort
  class Holding
    attr_accessor :primo_base_url, :primo_view_id, :primo_config
    attr_accessor :record_id, :original_source_id, :source_id, :source_record_id
    attr_accessor :institution, :library_code, :id_one, :id_two, :status_code, :status, :origin
    attr_accessor :call_number, :display_type
    attr_accessor :source_config, :text, :raw
    attr_accessor :match_reliability
    attr_reader :library, :collection_str
    attr_reader :primo_url, :url, :coverage_str, :notes
    attr_reader :action_url

    def initialize(e)
      unless e.nil?
        if e.kind_of? Holding
          @primo_config = e.primo_config
          @raw = e.raw
          @text = e.text
          @institution = e.institution
          @library_code = e.library_code
          @id_one = e.id_one
          @id_two = e.id_two
          @status_code = e.status_code
          @origin = e.origin
          @collection_str = e.collection_str
          @call_number = e.call_number
          @record_id = e.record_id
          @primo_base_url = e.primo_base_url
          @primo_view_id = e.primo_view_id
          @record_id = e.record_id
          @original_source_id = e.original_source_id
          @source_id = e.source_id
          @source_record_id = e.source_record_id
          @display_type = e.display_type
          @source_config = e.source_config
          @match_reliability = e.match_reliability
        elsif e.kind_of? Hpricot::Elem
          @primo_config = primo_config
          @raw = e 
          @text = raw.inner_text
          a = text.split(/\$(?=\$)/) unless raw.nil?
          a.each do |s|
            @institution = s.sub!(/^\$I/, "") unless s.match(/^\$I/).nil?
            @library_code = s.sub!(/^\$L/, "") unless s.match(/^\$L/).nil?
            @id_one = s.sub!(/^\$1/, "") unless s.match(/^\$1/).nil?
            @id_two = s.sub!(/^\$2/, "") unless s.match(/^\$2/).nil?
            # Always display "Check Availability" if this is from Primo.
            #@status_code = s.sub!(/^\$S/, "") unless s.match(/^\$S/).nil?
            @status_code = "check_holdings"
            @origin = s.sub!(/^\$O/, "") unless s.match(/^\$O/).nil?
          end
          @call_number = id_two
        end
      end
    end
    
    def primo_url
      return if primo_base_url.nil? or primo_view_id.nil? or record_id.nil?
      return primo_base_url + "/primo_library/libweb/action/dlDisplay.do?docId=" + record_id + "&institution=" + institution + "&vid=" + primo_view_id + "&reset_config=true"
    end
    
    def library
      h = primo_config["libraries"] unless primo_config.nil?
      map(library_code, h)
    end
    
    def status
      unless @status
        h = primo_config["statuses"] unless primo_config.nil?
        @status = map(status_code, h)
      end
      return @status
    end
    
    def collection_str
      library + " " + id_one
    end
    
    def url
      primo_url
    end

    def coverage_str
    end

    # Return an array of holding strings, possibly empty, possibly single-valued.
    # over-ridden by SerialCopy to give you an array, since SerialCopies have
    # multiple holdings strings. 
    def coverage_str_to_a
      return coverage_str.nil? ? [] : [coverage_str]
    end

    def notes
    end
    
    def to_a
      return [self]
    end
    
    def to_source
      source_class = source_config["class_name"] unless source_config.nil?
      if source_class.nil?
        s = self
      else
        s = Exlibris::Primo::Source.const_get(source_class).new(self)
      end
      return s
    end
    
    def max_holdings
      5
    end
    
    def dedup?
      return false
    end
    
    protected
    def map(str, h=nil)
      return str if (h.nil? or !h.kind_of? Hash)
      return (h[str].nil? ? str : h[str])
    end
  end
end
