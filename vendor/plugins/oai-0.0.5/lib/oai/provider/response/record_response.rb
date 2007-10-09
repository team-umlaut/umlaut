module OAI::Provider::Response
  class RecordResponse < Base

    def self.inherited(klass)
      klass.valid_parameters    :metadata_prefix, :from, :until, :set
      klass.default_parameters  :metadata_prefix => "oai_dc", 
            :from => Proc.new {|x| Time.parse(x.provider.model.earliest.to_s) },
            :until => Proc.new {|x| Time.parse(x.provider.model.latest.to_s) }
    end
    
    # emit record header
    def header_for(record)
      param = Hash.new
      param[:status] = 'deleted' if deleted?(record)
      @builder.header param do 
        @builder.identifier identifier_for(record)
        @builder.datestamp timestamp_for(record)
        sets_for(record).each do |set|
          @builder.setSpec set.spec
        end
      end
    end

    # metadata - core routine for delivering metadata records
    #
    def data_for(record)
      @builder.metadata do
        @builder.target! << provider.format(requested_format).encode(provider.model, record)
      end
    end
    
    private
    
    def identifier_for(record)
      "#{provider.prefix}/#{record.id}"
    end
    
    def timestamp_for(record)
      record.send(provider.model.timestamp_field).utc.xmlschema
    end
    
    def sets_for(record)
      return [] unless record.respond_to?(:sets) and record.sets
      record.sets.respond_to?(:each) ? record.sets : [record.sets]
    end
    
    def requested_format
      format = 
      if options[:metadata_prefix]
        options[:metadata_prefix]
      elsif options[:resumption_token]
        OAI::Provider::ResumptionToken.extract_format(options[:resumption_token])
      end

      raise OAI::FormatException.new unless provider.format_supported?(format)
      
      format
    end
    
    def deleted?(record)
      return record.deleted? if record.respond_to?(:deleted?)
      return record.deleted if record.respond_to?(:deleted)
      return record.deleted_at if record.respond_to?(:deleted_at)
      false
    end
    
  end
end