module Exlibris::Primo::Source
  # == Overview
  # Aleph is an Exlibris::Primo::Holding that provides a link to Aleph
  # and a request button based on config settings in the primo_config file.
  class Aleph < Exlibris::Primo::Holding
    @attribute_aliases = Exlibris::Primo::Holding.attribute_aliases.merge({
      :aleph_doc_library => :original_source_id, :aleph_sub_library => :library,
      :aleph_collection => :collection, :aleph_call_number => :call_number,
      :aleph_doc_number => :source_record_id
    })
    @decode_variables = Exlibris::Primo::Holding.decode_variables.merge({
      :aleph_sub_library_code => { :code => :library_code }
    })

    # Overwrites Exlibris::Primo::Holding#new
    def initialize(parameters={})
      super(parameters)
      @aleph_local_base = aleph_config["local_base"] unless aleph_config.nil?
      # Aleph holdings page
      @url = "#{@source_url}/F?func=item-global&doc_library=#{aleph_doc_library}&local_base=#{@aleph_local_base}&doc_number=#{aleph_doc_number}&sub_library=#{@aleph_sub_library_code}"
      # Aleph doesn't work right so we have to push the patron to the Aleph holdings page!
      @request_url = url if requestable?
      @source_data.merge!({
        :aleph_doc_library => aleph_doc_library,
        :aleph_sub_library => aleph_sub_library,
        :aleph_sub_library_code => @aleph_sub_library_code,
        :aleph_collection => aleph_collection,
        :aleph_call_number => aleph_call_number,
        :aleph_doc_number => aleph_doc_number
      })
    end

    protected
    # Maps @source config to aleph_config for convenience.
    def aleph_config
      return @source_config
    end

    private
    def requestable?
      # Default to nothing is requestable
      return false if aleph_config.nil? or aleph_config["requestable_statuses"].nil?
      return aleph_config["requestable_statuses"].include?(@status_code) 
    end
  end
end
