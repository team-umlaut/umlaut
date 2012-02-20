# encoding: UTF-8

module OpenURL
  
  # The ContextObjectEntity is a generic class to define an entity.  It should
  # not be initialized directly, only through one of its children: 
  #   ReferentEntity, ReferrerEntity, ReferringEntity, ResolverEntity, 
  #   ServiceTypeEntity, or CustomEntity
  
  class ContextObjectEntity
    # identifiers should always be an array, but it might be an empty one. 
    attr_reader(:identifiers, :reference, :format, :metadata, :private_data, :abbr, :label)
    
    def initialize
      @identifiers = []
      @reference = {"format"=>nil, "location"=>nil}
      @format = nil
      @metadata = {}
      @private_data = nil
    end
    
    # Sets the location and format of a by-reference context object entity
    
    def set_reference(loc, fmt)
      @reference["location"] = loc
      @reference["format"] = fmt
    end

    # Should really be called "add identifier", since we can have more
    # than one. But for legacy, it's "set_identifier". 
    def add_identifier(val)
      return if val.nil?      
      @identifiers.push( self.class.normalize_id(val) ) unless @identifiers.index(self.class.normalize_id(val))
    end
    alias :set_identifier :add_identifier

    def delete_identifier(val)
      return @identifiers.delete(val)
    end
     
    
    # We can actually have more than one, but certain code calls this
    # method as if there's only one. We return the first. 
    def identifier
      return @identifiers[0]
    end
    
    
    def set_private_data(val)
      @private_data = val
    end  

    def set_metadata(key, val)
      @metadata[key] = val
    end
    
    def get_metadata(key)
      return @metadata[key]
    end

    def set_format(format) 
      return unless format
      if format.match(/^info:ofi\/fmt/)      
        @format = format.split(":").last
      else
        @format = format
      end
    end        
    
    def self.new_from_format(format)
      if format.match(/^info:ofi\/fmt/)
        return ContextObjectEntityFactory.format( format )        
      else
        return self.new
      end
    end
    
    # Serializes the entity to XML and attaches it to the supplied REXML element.
    
    def xml(co_elem, label) 
      full_label = OpenURL::ContextObject.entities(label)
      meta = {"container"=>co_elem.add_element("ctx:#{full_label}")}          
      if @metadata.length > 0 or @format
        meta["metadata-by-val"] = meta["container"].add_element("ctx:metadata-by-val")
        if @format 
          meta["format"] = meta["metadata-by-val"].add_element("ctx:format")
          meta["format"].text = (@xml_ns||"info:ofi/fmt:xml:xsd:#{@format}")
        end
        if @metadata.length > 0
          self.serialize_metadata(meta["metadata-by-val"], label)
        end
      end
      if @reference["format"] 
        meta["metadata-by-ref"] = meta["container"].add_element("ctx:metadata-by-ref")
        meta["ref_format"] = meta["metadata-by-ref"].add_element("ctx:format")
        meta["ref_format"].text = @reference["format"]
        meta["ref_loc"] = meta["metadata-by-ref"].add_element("ctx:location")
        meta["ref_loc"].text = @reference["location"]          
      end
      
      @identifiers.each do |id|
        # Yes, meta["identifier"] will get over-written if there's more than
        # one identifier. But I dont' think this meta hash is used for much
        # I don't think it's a problem. -JR 
        meta["identifier"] = meta["container"].add_element("ctx:identifier")
        meta["identifier"].text = id
      end
      if @private_data
        meta["private-data"] = meta["container"].add_element("ctx:private-data")
        meta["private-data"].text = @private_data
      end          
      return co_elem
    end
    
    def serialize_metadata(elem, label)
      meta = {}
      metadata = elem.add_element("ctx:metadata")
      @metadata.each do |k,v|
        meta[k] = metadata.add_element("#{label}:"+k)
        meta[k].add_namespace(label, (@xml_ns||"info:ofi/fmt:xml:xsd:#{@format}"))
        meta[k].text = v
      end      
    end
            
    # Outputs the entity as a KEV array
    
    def kev(abbr)
      kevs = []
      
      @metadata.each do |k,v|
        kevs << "#{abbr}.#{k}="+CGI.escape(v) if v                      
      end
      if @kev_ns
        kevs << "#{abbr}_val_fmt="+CGI.escape(@kev_ns)
      elsif @format
        kevs << "#{abbr}_val_fmt="+CGI.escape("info:ofi/fmt:kev:mtx:#{@format}")
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
    
    # Outputs the entity as a hash
    # Outputting a context object as a hash
    # is imperfect, because context objects can have multiple elements
    # with the same key. So this function is really deprecated, but here
    # because we have so much code dependent on it.
    #
    # self does not know it's own entity abbreviation prefix, so must
    # be passed in.
    def to_hash(abbr)

      co_hash = {}
      
      @metadata.each do |k,v|
        co_hash["#{abbr}.#{k}"]=v if v
      end

      # Not sure what this should be? Can we know what it is set to, or
      # it's output dependent? If the latter, can't really know
      # anything, since this is just a hash! 
      co_hash["#{abbr}_val_fmt"]="info:ofi/fmt:kev:mtx:#{@format}" if @format              

      if @reference["format"] 
        co_hash["#{abbr}_ref_fmt"]=@reference["format"]
        co_hash["#{abbr}_ref"]=@reference["location"]
      end
      
      @identifiers.each do |id|
        # Put em in a list. 
        co_hash["#{abbr}_id"] ||= Array.new
        co_hash["#{abbr}_id"].push( id )
      end
      co_hash["#{abbr}_dat"]=@private_data if @private_data
              
      return co_hash    
    end    
    
    # Checks to see if the entity has any metadata set.
    
    def empty?
      return false if (@identifiers.length > 0 ) or @reference["format"] or @reference["location"] or @metadata.length > 0 or @format or @private_data              
      return true      
    end
    
    # Serializes the metadata values for Referent and ReferringEntity entities
    # since their schema is a little different.
    
    def xml_for_ref_entity(co_elem)      
      meta = {"container"=>co_elem.add_element("ctx:#{@label}")}

      if @metadata.length > 0 or @format
        meta["metadata-by-val"] = meta["container"].add_element("ctx:metadata-by-val")
        if @format 
          meta["format"] = meta["metadata-by-val"].add_element("ctx:format")
          meta["format"].text = "info:ofi/fmt:xml:xsd:#{@format}"

          if @metadata.length > 0
            meta["metadata"] = meta["metadata-by-val"].add_element("ctx:metadata")
            meta["format_container"] = meta["metadata"].add_element("rft:#{@format}")
            meta["format_container"].add_namespace(@abbr, meta["format"].text)
            meta["format_container"].add_attribute("xsi:schemaLocation", meta["format"].text+" http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:"+@format)          
            @metadata.each do |k,v|
              meta[k] = meta["format_container"].add_element("#{@abbr}:#{k}")
              meta[k].text = v
            end
          end
        end
      end
      if @reference["format"] 
        meta["metadata-by-ref"] = meta["container"].add_element("ctx:metadata-by-ref")
        meta["ref_format"] = meta["metadata-by-ref"].add_element("ctx:format")
        meta["ref_format"].text = @reference["format"]
        meta["ref_loc"] = meta["metadata-by-ref"].add_element("ctx:location")
        meta["ref_loc"].text = @reference["location"]          
      end
      
      @identifiers.each do |id|
        # Yes, if there's more than one, meta["identifier"] will get
        # overwritten with last. I don't think this is a problem, cause
        # meta["identifier"] isn't used anywhere. 
        meta["identifier"] = meta["container"].add_element("ctx:identifier")
        meta["identifier"].text = id
      end
      if @private_data
        meta["private-data"] = meta["container"].add_element("ctx:private-data")
        meta["private-data"].text = @private_data
      end          
      return co_elem
    end  

    # Switch old 0.1 style ids to new 1.0 style ids.
    # Eg, turn << doi:[x] >>    into     << info:doi/[x] >>
    # Looks for things that are NOT valid URI prefixes, but
    # were commonly used in OpenURL 0.1, and can be easily turned
    # into info URIs.  
    def self.normalize_id(value)
        value =~ /^(\w+)(\:|\/)(.*)/
        prefix = $1
        remainder = $3
        # info ones
        if ["doi", "pmid", "oclcnum", "sici", "lccn", "sid"].include?(prefix)
          value = "info:#{prefix}/#{remainder}"
        end
        # urn ones
        if ["isbn", "issn"].include?(prefix)
          value = "urn:#{prefix}:#{remainder}"
        end
        
        return value
    end
    
    def import_xml_metadata(node)
      mbv = REXML::XPath.first(node, "./ctx:metadata-by-val", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})

      if mbv        
        mbv.to_a.each do |m|
          self.set_metadata(m.name(), m.get_text.value) if m && m.get_text
        end
      end			
    end    
    
  end  
  
  class ContextObjectEntityFactory
    @@factories = []
    
    def self.inherited(factory)
      @@factories.insert(0,factory)
    end 
    
    def self.add_factory(factory)
      @@factories.insert(0,factory)
    end
    
    def self.delete_factory_at(index)
      @@factories.delete_at(index)
    end
    
    def self.format(format_id)      
      @@factories.each { |factory|        
        if factory.identifiers.index(format_id)
          return factory.create()
        end
      }
      ent = OpenURL::ContextObjectEntity.new
      ent.set_format(format_id)
      return ent
    end
    
    def self.factories
      return @@factories
    end
    
    def self.load(dirname)
      Dir.open( dirname ).each { |fn|
        next unless ( fn =~ /[.]rb$/ )
        require "#{dirname}/#{fn}"
      }
    end    
  end
end
