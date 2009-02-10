module Exlibris::Primo
  # Class for handling Primo Holdings from display/availlibrary
  # TODO: Should probably extend a base class of some sort
  class Holding
    attr_accessor :primo_base_url, :primo_view_id, :primo_config
    attr_accessor :record_id, :original_source_id, :source_id, :source_record_id
    attr_accessor :institution, :library_code, :id_one, :id_two, :status_code, :origin
    attr_accessor :call_number
    attr_accessor :source_config, :text, :raw
    attr_reader :library, :status, :collection_str
    attr_reader :primo_url, :url, :coverage_str, :notes
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
        elsif e.kind_of? REXML::Element
          @primo_config = primo_config
          @raw = e.text 
          # TODO: Further investigation, not sure what purpose text serves.
          @text = raw
          a = raw.split(/\$(?=\$)/) unless raw.nil?
          a.each do |s|
            @institution = s.sub!(/^\$I/, "") unless s.match(/^\$I/).nil?
            @library_code = s.sub!(/^\$L/, "") unless s.match(/^\$L/).nil?
            @id_one = s.sub!(/^\$1/, "") unless s.match(/^\$1/).nil?
            @id_two = s.sub!(/^\$2/, "") unless s.match(/^\$2/).nil?
            @status_code = s.sub!(/^\$S/, "") unless s.match(/^\$S/).nil?
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
      h = primo_config["statuses"] unless primo_config.nil?
      map(status_code, h)
    end
    
    def collection_str
      library# + id_one
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
    
    def to_source
      source_class = source_config["class_name"] unless source_config.nil?
      if source_class.nil?
        s = self
      else
        s = Exlibris::Primo::Source.const_get(source_class).new(source_config, self)
=begin
        s.institution = institution
        s.library = library
        s.id_one = id_one
        s.id_two = id_two
        s.status = status
        s.origin = origin
        s.collection_str = collection_str
        s.call_number = call_number
        s.record_id = record_id
        s.primo_base_url = primo_base_url
        s.primo_view_id = primo_view_id
        s.record_id = record_id
        s.original_source_id = original_source_id
        s.source_id = source_id
        s.source_record_id = source_record_id
=end
      end
      return s
    end
    private
    def map(str, h=nil)
      return str if (h.nil? or !h.kind_of? Hash)
      return (h[str].nil? ? str : h[str])
    end
  end
end