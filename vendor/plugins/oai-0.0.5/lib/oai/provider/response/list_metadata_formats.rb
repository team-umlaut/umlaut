module OAI::Provider::Response
  
  class ListMetadataFormats < Base
    
    def to_xml
      response do |r|
        r.ListMetadataFormats do 
          provider.formats.each do |key, format|
            r.metadataFormat do 
              r.metadataPrefix format.prefix
              r.schema format.schema
              r.metadataNamespace format.namespace
            end
          end
        end
      end
    end

  end  
  
end