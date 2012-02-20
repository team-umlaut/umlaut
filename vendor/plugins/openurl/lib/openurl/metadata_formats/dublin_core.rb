# encoding: UTF-8

# 
# dublin_core.rb
# 
# Created on Nov 12, 2007, 10:35:28 AM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 
module OpenURL
  class DublinCore < ContextObjectEntity
    def initialize      
      super
      @metadata_keys = ['title','creator','subject','description','publisher',
        'contributor','date','type','format','identifier','source', 'language',
        'relation', 'coverage', 'rights'
        ]      
      @xml_ns = "info:ofi/fmt:xml:xsd:oai_dc"
      @kev_ns = "info:ofi/fmt:kev:mtx:dc"
      @oai_ns = "http://www.openarchives.org/OAI/2.0/oai_dc/"
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
    
    def set_metadata(key, val)
      @metadata[key] ||=[]    
      @metadata[key] << val unless @metadata[key].index(val)
    end    
  

    def serialize_metadata(elem, label)
      meta = []
      fmt = elem.add_element("ctx:format")
      fmt.text = @xml_ns
      metadata = elem.add_element("ctx:metadata")
      dc_container = metadata.add_element("#{label}:dc")
      dc_container.add_namespace(label, @oai_ns)
      dc_container.add_namespace("dc", "http://purl.org/dc/elements/1.1/")
      dc_container.add_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")
      dc_container.add_attribute("xsi:schemaLocation", "http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd")
       
      @metadata.each do |key,vals|
        vals.each do | val |
          meta << dc_container.add_element("#{label}:#{key}")
          meta.last.text = val
        end
      end                 
    end 
    
    def import_xml_metadata(node)     
      mbv = REXML::XPath.first(node, "./ctx:metadata-by-val/ctx:metadata/fmt:dc", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx", "fmt"=>@oai_ns})					              
      if mbv
        mbv.to_a.each do |m|          
          m.children.each do | value|            
            self.set_metadata(m.name(), CGI.unescapeHTML(value.to_s))
          end
        end      
      end					
    end 
    
    def import_dc(dc)
      raise ArgumentError, "Argument must be a REXML::Document or String!" unless dc.is_a?(REXML::Document) or dc.is_a?(String)
      doc = dc
      doc = REXML::Document.new(dc) if doc.is_a?(String)
      doc.root.elements.each do | elem |
        self.set_metadata(elem.name(), CGI.unescapeHTML(elem.children.to_s)) unless elem.children.empty?                                  
      end
      
    end
    
    # Outputs the entity as a KEV array
    
    def kev(abbr)
      kevs = []
      
      @metadata.each do |key, vals|
        vals.each do | val |
          kevs << "#{abbr}.#{key}="+CGI.escape(val)
        end
      end
      
      kevs << "#{abbr}_val_fmt="+CGI.escape(@kev_ns)      
     
      
      if @reference["format"] 
        kevs << "#{abbr}_ref_fmt="+CGI.escape(@reference["format"])
        kevs << "#{abbr}_ref="+CGI.escape(@reference["location"])      
      end
      
      @identifiers.each do |id| 
          kevs << "#{abbr}_id="+CGI.escape(id)
      end
      
      kevs << "#{abbr}_dat="+CGI.escape(@private_data) if @private_data
                    
      return kevs      
    end    
  end
  
  class DublinCoreFactory < ContextObjectEntityFactory
    @@identifiers = ["info:ofi/fmt:kev:mtx:dc","info:ofi/fmt:xml:xsd:oai_dc"]
    def self.identifiers
      return @@identifiers
    end
    def self.create()
      return OpenURL::DublinCore.new
    end    
  end
end
