# encoding: UTF-8

# 
# scholarly_service_type.rb
# 
# Created on Nov 1, 2007, 10:35:28 AM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 
module OpenURL
  class ScholarlyServiceType < ContextObjectEntity    
    def initialize      
      super
      @format = 'sch_svc'      
      @metadata_keys = ['abstract','citation','fulltext','holdings','ill','any']      
      @xml_ns = "info:ofi/fmt:xml:xsd:sch_svc"
      @kev_ns = "info:ofi/fmt:kev:mtx:sch_svc"
    end    
    
    def method_missing(metadata, value=nil)
      meta = metadata.to_s.sub(/=$/,'')
      raise ArgumentError, "#{meta.to_s} is not a valid #{self.class} metadata field." unless @metadata_keys.index(meta)
      if metadata.to_s.match(/=$/)
        self.set_metadata(meta, value)
      else
        return self.metadata[meta]
      end
      
    end
     
  end
  
  class ScholarlyServiceTypeFactory < ContextObjectEntityFactory
    @@identifiers = ["info:ofi/fmt:kev:mtx:sch_svc","info:ofi/fmt:xml:xsd:sch_svc"]
    def self.identifiers
      return @@identifiers
    end
    def self.create()
      return OpenURL::ScholarlyServiceType.new
    end    
  end
end
