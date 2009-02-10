module Exlibris::Primo::Source
  class Aleph < Base
    attr_accessor :aleph_base_url, :aleph_library, :aleph_sub_library, :aleph_collection, :aleph_call_number
   
    def initialize(config, e=nil)
      super(config, e)
      @aleph_library = original_source_id
      @aleph_sub_library = library
      @aleph_collection = id_one
      @aleph_call_number = id_two
      @aleph_base_url = source_base_url
    end

    def aleph_bib_number
      source_record_id
    end

    def source_url
      aleph_base_url + "/F?func=item-global&doc_library=#{aleph_library}&local_base=PRIMOCOMMON&doc_number=#{aleph_bib_number}"
    end
    
    def url
      source_url
    end
  end
end
