module Exlibris::Primo::Source
  class Aleph < Exlibris::Primo::Source::Base
    attr_accessor :aleph_item_barcode, :aleph_sequence_number, :aleph_sub_library_code, :aleph_local_base
   
    def initialize(e=nil)
      super(e)
      h = primo_config["aleph_sub_library_codes"] unless primo_config.nil?
      @aleph_sub_library_code = map(library_code, h)
      @aleph_local_base = aleph_config["local_base"]
    end

    alias aleph_config source_config
    alias aleph_bib_library original_source_id
    alias aleph_sub_library library
    alias aleph_collection id_one
    alias aleph_call_number id_two
    alias aleph_base_url source_base_url
    alias aleph_bib_number source_record_id

    def source_url
      "#{aleph_base_url}/F?func=item-global&doc_library=#{aleph_bib_library}&local_base=#{aleph_local_base}&doc_number=#{aleph_bib_number}&sub_library=#{aleph_sub_library_code}"
    end
    
    def url
      source_url
    end
    
    def request_url
      # Aleph doesn't work right so we have to push the patron to the holdings screen!
      source_url if requestable?
      #"#{aleph_base_url}/F?func=item-hold-request&doc_library=NYU50&barcode=#{aleph_item_barcode}&local_base=PRIMOCOMMON" if requestable?
    end

    def requestable?
      # Default to nothing is requestable
      return false if request_statuses.nil?
      return request_statuses.include?(status_code) 
    end
    
    def request_statuses
      h = aleph_config["requestable_statuses"] unless aleph_config.nil?
    end
  end
end
