# encoding: UTF-8

# 
# marc.rb
# 
# Created on Nov 12, 2007, 10:35:28 AM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
require 'rubygems'
require 'marc'
module OpenURL
  class Marc < ContextObjectEntity
    private :kev, :set_metadata
    attr_accessor :marc
    def initialize      
      super    
      @xml_ns = "info:ofi/fmt:xml:xsd:MARC21"
      @format = @xml_ns
      @marc = MARC::Record.new
      @marc_ns = "http://www.loc.gov/MARC21/slim"
      @metadata = @marc.fields
    end    
    
    def serialize_metadata(elem, label)
      metadata = elem.add_element("ctx:metadata")
      if @marc.is_a?(Array)
        container = metadata.add_elements("#{label}:collection")
        container.add_namespace(label, @marc_ns)
        @marc.each do | mrc |
          rec = mrc.to_xml.root          
          mrc_elem = container.add_element rec
          mrc_elem.name = "#{label}:#{mrc_elem.name}"
        end
      else
        rec = @marc.to_xml.root 
        rec.add_namespace(label, @marc_ns)
        rec.name = "#{label}:#{rec.name}"
        mrc_elem = metadata.add_element rec                                
      end      
    end 
    
    def import_xml_metadata(node)         
      marcxml = REXML::XPath.first(node,"./ctx:metadata-by-val/ctx:metadata/fmt:collection | ./ctx:metadata-by-val/ctx:metadata/fmt:record", 
        {"ctx"=>"info:ofi/fmt:xml:xsd:ctx","fmt"=>@marc_ns})
      if marcxml
        marcxml.root.prefix = ''
        records = []
        MARC::XMLReader.new(StringIO.new(marcxml.to_s)).each do | record |
          records << record
        end
        if records.length == 1
          @marc = records[0]
        else
          @marc = records
        end
      end
      @metadata = @marc.fields
    end 
     
  end
  
  class MarcFactory < ContextObjectEntityFactory
    @@identifiers = ["info:ofi/fmt:xml:xsd:MARC21"]
    def self.identifiers
      return @@identifiers
    end
    def self.create()
      return OpenURL::Marc.new
    end    
  end
end
