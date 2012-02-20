# encoding: UTF-8

# 
# patent.rb
# 
# Created on Nov 1, 2007, 10:35:28 AM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 
require 'openurl/metadata_formats/scholarly_common'
module OpenURL
  class Patent < ContextObjectEntity
    attr_reader :inventors
    def initialize      
      super
      @format = 'patent'
      @inventors = [OpenURL::Inventor.new]
      @metadata_keys = ['title','co','cc','kind','applcc','applnumber','number',
        'date','applyear','appldate','assignee','pubdate','prioritydate'
        ]
      @inventor_keys = ['inv', 'invlast', 'invfirst']
      @xml_ns = "info:ofi/fmt:xml:xsd:patent"
      @kev_ns = "info:ofi/fmt:kev:mtx:patent"
    end    
    
    def method_missing(metadata, value=nil)
      meta = metadata.to_s.sub(/=$/,'')
      raise ArgumentError, "#{meta.to_s} is not a valid #{self.class} metadata field." unless (@inventor_keys+@metadata_keys).index(meta)
      if metadata.to_s.match(/=$/)
        self.set_metadata(meta, value)
        if @inventor_keys.index(meta)
          @inventors[0].instance_variable_set("@#{meta}", value)
        end
      else
        return self.metadata[meta]
      end
      
    end
    
    def set_metadata(key, val)
      @metadata[key] = val
      if @inventor_keys.index(key)
        @inventors[0].instance_variable_set("@#{key}", val)
      end      
    end    

    def add_inventor(inventor)
      raise ArgumentError, "Argument must be an OpenURL::Author!" unless inventor.is_a?(OpenURL::Inventor)
      @inventors << inventor
    end
    
    def remove_inventor(inventor)
      idx = inventor
      idx = @inventors.index(inventor)
      raise ArgumentError unless idx
      @authors.delete_at(idx)      
    end    

    def serialize_metadata(elem, label)
      meta = {}
      metadata = elem.add_element("ctx:metadata")
      meta["format_container"] = metadata.add_element("#{label}:#{@format}")
      meta["format_container"].add_namespace(label, @xml_ns)
      meta["format_container"].add_attribute("xsi:schemaLocation", "#{@xml_ns} http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:#{@format}")          
      @metadata.each do |k,v|
        next if ['inv', 'invlast', 'invfirst'].index(k)
        meta[k] = meta["format_container"].add_element("#{label}:#{k}")
        meta[k].text = v
      end            
      meta["inventor_container"] = meta["format_container"].add_element("#{label}:inventors")
      @inventors.each do | inventor |
        inventor.xml(meta["inventor_container"])
      end      
    end 
    def import_xml_metadata(node)         
      mbv = REXML::XPath.first(node, "./ctx:metadata-by-val/ctx:metadata/fmt:#{@format}", {"fmt"=>@xml_ns})					              
      if mbv
        mbv.to_a.each do |m|
          self.set_metadata(m.name(), m.get_text.value) if m.has_text?                                  
          if m.has_elements?
            m.to_a.each do | md |
              self.set_metadata(md.name(), md.get_text.value) if md.has_text?                              
            end
          end
        end
        inv_num = 0
        REXML::XPath.each(mbv, "fmt:inventors/fmt:inventor | fmt:inventor/fmt:inv", {"fmt"=>@xml_ns}) do | inventor |                    
          empty_node = true
          if inventor.name == "inventor"            
            inventor.elements.each do | inv_elem |            
              next unless @inventor_keys.index(inv_elem.name) and inv_elem.has_text?
              empty_node = false
              @inventors << OpenURL::Inventor.new unless @inventors[inv_num]
              @inventors[inv_num].instance_variable_set("@#{inv_elem.name}".to_sym, inv_elem.get_text.value)
              self.set_metadata(inv_elem.name, inv_elem.get_text.value) if inv_num == 0
            end
          elsif inventor.name.match(/^inv$/)
            next unless inventor.has_text? 
            empty_node = false
            @inventors << OpenURL::Inventor.new unless @inventors[inv_num]
            @inventors[inv_num]["inv"] = inventor.get_text.value
            self.set_metadata("inv", inventor.get_text.value) if inv_num == 0            
          end
          inv_num += 1 unless empty_node
        end        
      end					
    end 
    
    # Outputs the entity as a KEV array
    
    def kev(abbr)
      kevs = []
      
      @metadata_keys.each do |key|
        kevs << "#{abbr}.#{key}="+CGI.escape(@metadata[key]) if @metadata[key]                      
      end
      
      kevs << "#{abbr}_val_fmt="+CGI.escape(@kev_ns)      
      
      if @inventors[0] and not @inventors[0].empty?
        @inventor_keys.each do | ikey |
          key = ikey
          key = "inventor" if ikey == "inv"          
          kevs << "#{abbr}.#{key}="+CGI.escape(@inventors[0].ikey) if @inventors[0].ikey          
        end
        
      end
      
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
  
  class PatentFactory < ContextObjectEntityFactory
    @@identifiers = ["info:ofi/fmt:kev:mtx:patent","info:ofi/fmt:xml:xsd:patent"]
    def self.identifiers
      return @@identifiers
    end
    def self.create()
      return OpenURL::Patent.new
    end    
  end
end
