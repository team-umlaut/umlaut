module OAI::Provider::Response
  
  class Identify < Base
    
    def to_xml
      response do |r|
        r.Identify do
          r.repositoryName provider.name
          r.baseURL provider.url
          r.protocolVersion 2.0
          provider.email.each do |address|
            r.adminEmail address
          end if provider.email
          r.earliestDatestamp provider.model.earliest
          r.deleteRecord provider.delete_support.to_s
          r.granularity provider.granularity
        end
      end
    end
    
  end
  
end
  