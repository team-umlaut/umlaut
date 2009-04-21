module Exlibris::Primo::Source
  class Aleph < Base
    attr_accessor :aleph_item_barcode, :aleph_sequence_number
   
    def initialize(e=nil)
      super(e)
    end

    alias aleph_config source_config
    alias aleph_library original_source_id
    alias aleph_sub_library library
    alias aleph_collection id_one
    alias aleph_call_number id_two
    alias aleph_base_url source_base_url
    alias aleph_bib_number source_record_id

    def source_url
      "#{aleph_base_url}/F?func=item-global&doc_library=#{aleph_library}&local_base=PRIMOCOMMON&doc_number=#{aleph_bib_number}&sub_library=#{sub_library_code}"
    end
    
    def request_url
      # Aleph doesn't work right so we have to push the patron to the holdings screen!
      source_url if requestable?
      #"#{aleph_base_url}/F?func=item-hold-request&doc_library=NYU50&barcode=#{aleph_item_barcode}&local_base=PRIMOCOMMON&adm_doc_number=#{aleph_bib_number}" unless aleph_item_barcode.nil? or !requestable?
    end
    
    def url
      source_url
    end
    
    def sub_library_code
      h = aleph_config["sub_libraries"] unless aleph_config.nil?
      map(aleph_sub_library, h)
    end
    
    def requestable?
      # Default to everything is requestable (why not be optimistic?!)
      return true if request_statuses.nil?
      return request_statuses.include?(status_code) 
    end
    
    def request_statuses
      h = aleph_config["requestable_statuses"] unless aleph_config.nil?
    end
  end
end
