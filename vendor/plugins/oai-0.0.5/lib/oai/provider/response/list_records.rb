module OAI::Provider::Response

  class ListRecords < RecordResponse
    
    def to_xml
      result = provider.model.find(:all, options)
      # result may be an array of records, or a partial result
      records = result.respond_to?(:records) ? result.records : result

      raise OAI::NoMatchException.new if records.nil? or records.empty?

      response do |r|
        r.ListRecords do
          records.each do |rec|
            r.record do
              header_for rec
              data_for rec unless deleted?(rec)
            end
          end
        end

        # append resumption token for getting next group of records
        if result.respond_to?(:token)
          r.target! << result.token.to_xml
        end
      end
    end
    
  end
  
end
  
