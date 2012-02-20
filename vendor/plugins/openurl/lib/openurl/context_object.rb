# encoding: UTF-8

module OpenURL

  if RUBY_VERSION < '1.9'
    require 'jcode'
    $KCODE='UTF-8'
  end

  ## 
  # The ContextObject class is intended to both create new OpenURL 1.0 context
  # objects or parse existing ones, either from Key-Encoded Values (KEVs) or
  # XML.
  # == Create a new ContextObject programmatically 
  #   require 'openurl/context_object'
  #   include OpenURL
  # 
  #   ctx = ContextObject.new
  #   ctx.referent.set_format('journal') # important to do this FIRST.
  # 
  #   ctx.referent.add_identifier('info:doi/10.1016/j.ipm.2005.03.024')
  #   ctx.referent.set_metadata('issn', '0306-4573')
  #   ctx.referent.set_metadata('aulast', 'Bollen')
  #   ctx.referrer.add_identifier('info:sid/google')
  #   puts ctx.kev
  #   # url_ver=Z39.88-2004&ctx_tim=2007-10-29T12%3A18%3A53-0400&ctx_ver=Z39.88-2004&ctx_enc=info%3Aofi%2Fenc%3AUTF-8&ctx_id=&rft.issn=0306-4573&rft.aulast=Bollen&rft_val_fmt=info%3Aofi%2Ffmt%3Axml%3Axsd%3Ajournal&rft_id=info%3Adoi%2F10.1016%2Fj.ipm.2005.03.024&rfr_id=info%3Asid%2Fgoogle
  #
  # == Create a new ContextObject from an existing kev or XML serialization:
  #
  # ContextObject.new_from_kev(   kev_context_object )
  # ContextObject.new_from_xml(   xml_context_object ) # Can be String or REXML::Document
  #
  # == Serialize a ContextObject to kev or XML :
  # ctx.kev
  # ctx.xml
  class ContextObject    

    attr_reader :admin, :referent, :referringEntity, :requestor, :referrer, 
      :serviceType, :resolver
    attr_accessor :foreign_keys
    
    @@defined_entities = {"rft"=>"referent", "rfr"=>"referrer", "rfe"=>"referring-entity", "req"=>"requestor", "svc"=>"service-type", "res"=>"resolver"}
    
    # Creates a new ContextObject object and initializes the ContextObjectEntities.
    
    def initialize()       
      @referent = ContextObjectEntity.new
      @referrer = ContextObjectEntity.new
      @referringEntity = ContextObjectEntity.new
      @requestor = ContextObjectEntity.new
      @serviceType = []
      @resolver = []
      @foreign_keys = {}
      @admin = {"ctx_ver"=>{"label"=>"version", "value"=>"Z39.88-2004"}, "ctx_tim"=>{"label"=>"timestamp", "value"=>DateTime.now().to_s}, "ctx_id"=>{"label"=>"identifier", "value"=>""}, "ctx_enc"=>{"label"=>"encoding", "value"=>"info:ofi/enc:UTF-8"}}    
    end

    def deep_copy
      cloned = ContextObject.new
      cloned.import_context_object( self )
      return cloned
    end
    
    # Serialize the ContextObject to XML.
    
    def xml      
      doc = REXML::Document.new()
      coContainer = doc.add_element "ctx:context-objects"
      coContainer.add_namespace("ctx","info:ofi/fmt:xml:xsd:ctx")
      coContainer.add_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")
      coContainer.add_attribute("xsi:schemaLocation", "info:ofi/fmt:xml:xsd:ctx http://www.openurl.info/registry/docs/info:ofi/fmt:xml:xsd:ctx")
      co = coContainer.add_element "ctx:context-object"
      @admin.each_key do |k|
        next if k == "ctx_enc"
        co.add_attribute(@admin[k]["label"], @admin[k]["value"])
      end

      [{@referent=>"rft"}, 
        {@referringEntity=>"rfe"}, {@requestor=>"req"},        
        {@referrer=>"rfr"}].each do | entity |
        
        entity.each do | ent, label |
          ent.xml(co, label) unless ent.empty?
        end
      end
      
      [{@serviceType=>"svc"}, {@resolver=>"res"}].each do |entity|
        entity.each do | entCont, label |        
          entCont.each do |ent|
            ent.xml(co, label) unless ent.empty?                      
          end
        end
      end

      return doc.to_s
    end
    
    
    # Output the ContextObject as a Key-encoded value string.  Pass a boolean
    # true argument if you do not want the ctx_tim key included.
    
    def kev(no_date=false)
      kevs = ["url_ver=Z39.88-2004", "url_ctx_fmt=#{CGI.escape("info:ofi/fmt:kev:mtx:ctx")}"]
      
      # Loop through the administrative metadata      
      @admin.each_key do |k|
        next if k == "ctx_tim" && no_date                    
        kevs.push(k+"="+CGI.escape(@admin[k]["value"].to_s)) if @admin[k]["value"]                  
      end

      {@referent=>"rft", @referringEntity=>"rfe", @requestor=>"req", @referrer=>"rfr"}.each do | ent, abbr |
        kevs.push(ent.kev(abbr)) unless ent.empty?                  
      end
      
      {@serviceType=>"svc", @resolver=>"res"}.each do |entCont, abbr|        
        entCont.each do |ent|
          next if ent.empty?          
          kevs.push(ent.kev(abbr))
        end
      end        
      return kevs.join("&")
    end
    
    # Outputs the ContextObject as a ruby hash---hash version of the kev format.
    # Outputting a context object as a hash
    # is imperfect, because context objects can have multiple elements
    # with the same key--and because some keys depend on SAP1 vs SAP2.
    # So this function is really deprecated, but here because we have so much 
    # code dependent on it.
    def to_hash            
      co_hash = {"url_ver"=>"Z39.88-2004", "url_ctx_fmt"=>"info:ofi/fmt:kev:mtx:ctx"}           
      
      @admin.each_key do |k|
        co_hash[k]=@admin[k]["value"] if @admin[k]["value"]
      end

      {@referent=>"rft", @referringEntity=>"rfe", @requestor=>"req", @referrer=>"rfr"}.each do | ent, abbr |
        co_hash.merge!(ent.to_hash(abbr)) unless ent.empty?
      end

      # svc  and res are arrays of ContextObjectEntity
      {@serviceType=>"svc", @resolver=>"res"}.each do |ent_list, abbr|        
        ent_list.each do |ent|
          co_hash.merge!(ent.to_hash(abbr)) unless ent.empty?
        end
      end        
      return co_hash
    end    
    
    
    # Outputs a COinS (ContextObject in SPANS) span tag for the ContextObject.
    # Arguments are any other CSS classes you want included and the innerHTML 
    # content.
    
    def coins (classnames=nil, innerHTML=nil)      
      return "<span class='Z3988 #{classnames}' title='"+CGI.escapeHTML(self.kev(true))+"'>#{innerHTML}</span>"
    end
       
    
    # Sets a ContextObject administration field.
    
    def set_administration_key(key, val)
      raise ArgumentException, "#{key} is not a valid admin key!" unless @admin.keys.index(key)
      @admin[key]["value"] = val
    end

    # Imports an existing Key-encoded value string and sets the appropriate 
    # entities.
    
    def import_kev(kev)      
      co = CGI::parse(kev)
      co2 = {}
      co.each do |key, val|
        if val.is_a?(Array)
          if val.length == 1
            co2[key] = val[0]
          else
            co2[key] = val
          end        
        end      	
      end
      self.import_hash(co2)
    end
    
    # Initialize a new ContextObject object from an existing KEV
    
    def self.new_from_kev(kev)
      co = self.new
      co.import_kev(kev)
      return co
    end 

    # Initialize a new ContextObject object from a CGI.params style hash
    # Expects a hash with default value being nil though, not [] as CGI.params
    # actually returns, beware. Can also accept a Rails-style params hash
    # (single string values, not array values), although this may lose
    # some context object information. 
    def self.new_from_form_vars(params)
      co = self.new
      if ctx_val = (params[:url_ctx_val]||params["url_ctx_val"]) and not ctx_val.empty? # this is where the context object stuff will be
        co.admin.keys.each do | adm |
          if params[adm.to_s]
            if params[adm.to_s].is_a?(Array)
              co.set_administration_key(adm, params[adm.to_s].first) 
            else
              co.set_administration_key(adm, params[adm.to_s]) 
            end
          end
        end
        
        if ctx_format = (params["url_ctx_fmt"]||params[:url_ctx_fmt])
          ctx_format = ctx_format.first if ctx_format.is_a?(Array)
          ctx_val = ctx_val.first if ctx_val.is_a?(Array)        
          if ctx_format  == "info:ofi/fmt:xml:xsd:ctx"
            co.import_xml(ctx_val)
          elsif ctx_format == "info:ofi/fmt:kev:mtx:ctx"
            co.import_kev(ctx_val)
          end
        end  
      else # we'll assume this is standard inline kev
        co.import_hash(params)
      end
      return co
    end
    
    # Imports an existing XML encoded context object and sets the appropriate
    # entities
    
    def import_xml(xml)			
      if xml.is_a?(String)
        doc = REXML::Document.new xml.gsub(/>[\s\t]*\n*[\s\t]*</, '><').strip
      elsif xml.is_a?(REXML::Document)
        doc = xml
      else
        raise ArgumentError, "Argument must be an REXML::Document or well-formed XML string"
      end
      
      # Cut to the context object
      ctx = REXML::XPath.first(doc, ".//ctx:context-object", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})



      

      
      ctx.attributes.each do |attr, val|				
        @admin.each do |adm, vals|
          self.set_administration_key(adm, val) if vals["label"] == attr											
        end
      end
      ctx.to_a.each do | ent |
        if @@defined_entities.value?(ent.name())
          self.import_entity(ent)
        else
          self.import_custom_node(ent)
        end
      end
    end
    
    # Initialize a new ContextObject object from an existing XML ContextObject
    
    def self.new_from_xml(xml)
      co = self.new
      co.import_xml(xml)
      return co
    end
    
    # Imports an existing hash of ContextObject values and sets the appropriate
    # entities.
    
    def import_hash(hash)            
      ref = {}
      {"@referent"=>"rft", "@referrer"=>"rfr", "@referringEntity"=>"rfe",
        "@requestor"=>"req"}.each do | ent, abbr |
        next unless hash["#{abbr}_val_fmt"]    
        val = hash["#{abbr}_val_fmt"]
        val = val[0] if val.is_a?(Array)
        self.instance_variable_set(ent.to_sym, ContextObjectEntityFactory.format(val))
      end
      
      {"@serviceType"=>"svc","@resolver"=>"res"}.each do | ent, abbr |
        next unless hash["#{abbr}_val_fmt"]
        val = hash["#{abbr}_val_fmt"]
        val = val[0] if val.is_a?(Array)        
        self.instance_variable_set(ent.to_sym, [ContextObjectEntityFactory.format(val)])
      end  

      openurl_keys = ["url_ver", "url_tim", "url_ctx_fmt"]
      hash.each do |key, value|      
        val = value
        val = value[0] if value.is_a?(Array)

        next if value.nil? || value.empty?
        
        if openurl_keys.include?(key)          
          next # None of these matter much for our purposes
        elsif @admin.has_key?(key)          
          self.set_administration_key(key, val) 
        elsif key.match(/^[a-z]{3}_val_fmt/)        
          next
        elsif key.match(/^[a-z]{3}_ref/)
          # determines if we have a by-reference context object
          (entity, v, fmt) = key.split("_")
          ent = self.translate_abbr(entity)
          unless ent
            self.foreign_keys[key] = val
            next
          end
          # by-reference requires two fields, format and location, if this is
          # the first field we've run across, set a place holder until we get
          # the other value          
          unless ref[entity]
            if fmt
              ref_key = "format"
            else 
              ref_key = "location"
            end
            ref[entity] = [ref_key, val]
          else
            if ref[entity][0] == "format"
              eval("@"+ent).set_reference(val, ref[entity][1])
            else
              eval("@"+ent).set_reference(ref[entity][1], val)
            end
          end
        elsif key.match(/^[a-z]{3}_id$/)
          # Get the entity identifier
          (entity, v) = key.split("_")
          ent = self.translate_abbr(entity)
          unless ent
            self.foreign_keys[key] = val
            next
          end
          # May or may not be an array, turn it into one.
          [value].flatten.each do | id |
            eval("@"+ent).add_identifier(id)
          end
                  
        elsif key.match(/^[a-z]{3}_dat$/)
          # Get any private data          
          (entity, v) = key.split("_")
          ent = self.translate_abbr(entity)
          unless ent
            self.foreign_keys[key] = val
            next
          end          
          eval("@"+ent).set_private_data(val)  
        else
          # collect the entity metadata
          keyparts = key.split(".")            
          if keyparts.length > 1
            # This is 1.0 OpenURL
            ent = self.translate_abbr(keyparts[0])
            unless ent
              self.foreign_keys[key] = val
              next
            end            
            eval("@"+ent).set_metadata(keyparts[1], val)
          else
            # This is a 0.1 OpenURL.  Your mileage may vary on how accurately
            # this maps.
            if key == 'id'
              if value.is_a?(Array)
                value.each do | id |
                  @referent.add_identifier(id)
                end
              else
                @referent.add_identifier(val)
              end              
            elsif key == 'sid'
              @referrer.set_identifier("info:sid/"+val.to_s) 
            elsif key == 'pid'
              @referent.set_private_data(val.to_s)           
            else 
              @referent.set_metadata(key, val)
            end
          end
        end
      end  
      
      # Initialize a new ContextObject object from an existing key/value hash
      
      def self.new_from_hash(hash)
        co = self.new
        co.import_hash(hash)
        return co
      end
      
      # if we don't have a referent format (most likely because we have a 0.1
      # OpenURL), try to determine something from the genre.  If that doesn't 
      # exist, just call it a journal since most 0.1 OpenURLs would be one,
      # anyway.
      unless @referent.format        
        fmt = case @referent.metadata['genre']
        when /article|journal|issue|proceeding|conference|preprint/ then 'journal'
        when /book|bookitem|report|document/ then 'book'
        else 'journal'
        end
        @referent.set_format(fmt)
      end
    end
    
    # Translates the abbreviated entity (rft, rfr, etc.) to the associated class
    # name.  For repeatable entities, uses the first object in the array.  Returns
    # a string of the object name which would then be eval'ed to call a method
    # upon.
    
    def translate_abbr(abbr)
      if @@defined_entities.has_key?(abbr)
        ent = @@defined_entities[abbr]
        if ent == "service-type"
          ent = "serviceType[0]"
        elsif ent == "resolver"
          ent = "resolver[0]"
        elsif ent == "referring-entity"      
          ent = "referringEntity"
        end
      else
        return nil
      end
      return ent
    end
    
    def self.entities(term)
      return @@defined_entities[term] if @@defined_entities.keys.index(term)
      return @@defined_entities[@@defined_entities.values.index(term)] if @@defined_entities.values.index(term)
      return nil
      
    end
    
    # Imports an existing OpenURL::ContextObject object and sets the appropriate
    # entity values.
    
    def import_context_object(context_object)
      @admin.each_key { |k|
        self.set_administration_key(k, context_object.admin[k]["value"])
      }	
      ["@referent", "@referringEntity", "@requestor", "@referrer"].each do | ent |
        self.instance_variable_set(ent.to_sym, Marshal::load(Marshal.dump(context_object.instance_variable_get(ent.to_sym))))
      end
      context_object.serviceType.each { |svc|        
        @serviceType << Marshal::load(Marshal.dump(svc))          
      }
      context_object.resolver.each { |res|
        @resolver << Marshal::load(Marshal.dump(res))                  
      }      
      context_object.foreign_keys.each do | key, val |
        self.foreign_keys[key] = val
      end
    end
    
    # Initialize a new ContextObject object from an existing 
    # OpenURL::ContextObject

    def self.new_from_context_object(context_object)
      co = self.new
      co.import_context_object(context_object)
      return co
    end       
    
    def referent=(entity)
      raise ArgumentError, "Referent must be an OpenURL::ContextObjectEntity" unless entity.is_a?(OpenURL::ContextObjectEntity)
      @referent=entity
    end
    
    def referrer=(entity)
      raise ArgumentError, "Referrer must be an OpenURL::ContextObjectEntity" unless entity.is_a?(OpenURL::ContextObjectEntity)
      @referrer=entity
    end    

    def referringEntity=(entity)
      raise ArgumentError, "Referring-Entity must be an OpenURL::ContextObjectEntity" unless entity.is_a?(OpenURL::ContextObjectEntity)
      @referringEntity=entity
    end    
    
    def requestor=(entity)
      raise ArgumentError, "Requestor must be an OpenURL::ContextObjectEntity" unless entity.is_a?(OpenURL::ContextObjectEntity)
      @requestor=entity
    end
    
    protected
    
    def import_entity(node)
      entities = {"rft"=>:@referent, "rfr"=>:@referrer, "rfe"=>:@referringEntity,"req"=>:@requestor,
        "svc"=>:@serviceType,"res"=>:@resolver}

      ent = @@defined_entities.keys[@@defined_entities.values.index(node.name())]


      metalib_workaround(node)
      
      unless ["svc","res"].index(ent)        
        self.instance_variable_set(entities[ent], self.set_typed_entity(node))
        entity = self.instance_variable_get(entities[ent])


        
        self.import_xml_common(entity, node)
        entity.import_xml_metadata(node)
      end
    end    
		
    def import_svc_node(node)
      if @serviceType[0].empty?
        key = 0
      else
        key = self.add_service_type_entity
      end
      self.import_xml_common(@serviceType[key], node)				
      self.import_xml_mbv(@serviceType[key], node)			
    end
		
    def import_res_node(node)
      if @resolver[0].empty?
        key = 0
      else
        key = self.add_resolver_entity
      end
      self.import_xml_common(@resolver[key], node)	
      self.import_xml_mbv(@resolver[key], node)			
    end

    # Determines the proper subclass of ContextObjectEntity to use
    # for given format. Input is an REXML node representing a ctx:referent.
    # Returns ContextObjectEntity. 
    def set_typed_entity(node)
      fmt = REXML::XPath.first(node, "./ctx:metadata-by-val/ctx:format", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})

      fmt_val = fmt.get_text.value if fmt && fmt.has_text?
      
      # Special weird workaround for info sent from metalib.
      # "info:ofi/fmt:xml:xsd" is not actually a legal format
      # identifier, it should have more on the end.
      # XPath should really end in "rft:*" for maximal generality, but 
      # REXML doesn't like that. 
      if (false && fmt_val && fmt_val == "info:ofi/fmt:xml:xsd")
        metalib_evidence = REXML::XPath.first( node, "./ctx:metadata-by-val/ctx:metadata/rft:journal", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx", "rft"=>"info:ofi/fmt:xml:xsd:journal"})
        
        # Okay, even if we don't have that one, do we have a REALLY bad one
        # where Metalib puts an illegal namespace identifier in too?
        metalib_evidence = REXML::XPath.first( node, "./ctx:metadata-by-val/ctx:metadata/rft:journal", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx", "rft"=>"info:ofi/fmt:xml:xsd"}) unless metalib_evidence
        
       # metalib didn't advertise it properly, but it's really
       # journal format.
       fmt_val = "info:ofi/fmt:xml:xsd:journal" if metalib_evidence
      end          
      
      if fmt_val
        return OpenURL::ContextObjectEntityFactory.format(fmt_val)
      else   
        return OpenURL::ContextObjectEntity.new
      end
    end
    
    # Parses the data that should apply to all XML context objects    
    def import_xml_common(ent, node)
      
      
      REXML::XPath.each(node, "./ctx:identifier", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"}) do | id |
        ent.add_identifier(id.get_text.value) if id and id.has_text?
      end

      priv = REXML::XPath.first(node, "./ctx:private-data", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})
      ent.set_private_data(priv.get_text.value) if priv and priv.has_text?

      ref = REXML::XPath.first(node, "./ctx:metadata-by-ref", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})					
      if ref
        reference = {}
        ref.to_a.each do |r|          
          if r.name() == "format"
            reference[:format] = r.get_text.value if r.get_text
          else 
            reference[:location] = r.get_text.value
          end					
        end
        ent.set_reference(reference[:location], reference[:format])
      end
    end

    # Pass in a REXML element representing an entity. 
    # Special weird workaround for info sent from metalib.
    # Metalib uses "info:ofi/fmt:xml:xsd" as a format identifier, and
    # sometimes even as a namespace identifier for a <journal> element.
    # It's not legal for either. It messes up our parsing. The identifier
    # should have something else on the end ":journal", ":book", etc.
    # We tack ":journal" on the end if we find this unspecified
    # but it contains a <journal> element. 
    # XPath should really end in "rft:*" for maximal generality, but 
    # REXML doesn't like that.   
    def metalib_workaround(node)
      # Metalib fix
      # Fix awful illegal Metalib XML
      fmt = REXML::XPath.first(node, "./ctx:metadata-by-val/ctx:format", {"ctx"=>"info:ofi/fmt:xml:xsd:ctx"})
      if ( fmt && fmt.text == "info:ofi/fmt:xml:xsd")
        metadata_by_val =  node.children.find {|e| e.respond_to?(:name) && e.name == 'metadata-by-val' }

        # Find a "journal" element to make sure forcing to ":journal" is a good
        # idea, and to later
        # fix the journal namespace if needed
        metadata = metadata_by_val.children.find {|e| e.respond_to?(:name) && e.name == 'metadata' } if metadata_by_val
        journal = metadata.find {|e| e.respond_to?(:name) && e.name == 'journal' } if metadata

        # Fix the format only if there's a <journal> element in there. 
        fmt = metadata_by_val.children.find {|e| e.respond_to?(:name) && e.name == 'format' } if metadata_by_val && journal       
        fmt.text = "info:ofi/fmt:xml:xsd:journal" if fmt
        
        if (journal && journal.namespace == "info:ofi/fmt:xml:xsd")
          journal.add_namespace("xmlns:rft", "info:ofi/fmt:xml:xsd:journal")
        end
      end
    end  
   
  end

  
end
