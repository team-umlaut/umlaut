class Referent < ActiveRecord::Base
  
  has_many :requests
  has_many :referent_values
  has_many :permalinks
  
  # When provided an OpenURL::ContextObject, it will return a Referent object (if one exists)
  def self.find_by_context_object(co)
    
    rft = co.referent

    # First try to find by id. There could be several. 
    rft.identifiers.each do | ident |
      if rft_val = ReferentValue.find_by_key_name_and_normalized_value('identifier', ReferentValue.normalize(ident))
        return rft_val.referent 
      end
    end
    
    shortcuts = {:atitle=>"", :title=>"", :issn=>"", :isbn=>"", :volume=>"", :year=>""}    
    shortcuts[:atitle] = ReferentValue.normalize(rft.metadata['atitle'])[0..254] if rft.metadata['atitle']
    if rft.metadata['jtitle']
      shortcuts[:title] = ReferentValue.normalize(rft.metadata['jtitle'])[0..254]
    elsif rft.metadata['btitle']
      shortcuts[:title] = ReferentValue.normalize(rft.metadata['btitle'])[0..254]
    elsif rft.metadata['title']
      shortcuts[:title] = ReferentValue.noramlize(rft.metadata['title'])[0..254]      
    end
    
    shortcuts[:issn] = ReferentValue.normalize(rft.metadata['issn']) if rft.metadata['issn']
    shortcuts[:isbn] = ReferentValue.normalize(rft.metadata['isbn']) if rft.metadata['isbn']    
    shortcuts[:volume] = ReferentValue.normalize(rft.metadata['volume']) if rft.metadata['volume']
    shortcuts[:year] = ReferentValue.normalize(rft.metadata['date']) if rft.metadata['date']
    
    return nil unless rft = Referent.find_by_atitle_and_title_and_issn_and_isbn_and_volume_and_year(shortcuts[:atitle],
      shortcuts[:title], shortcuts[:issn], shortcuts[:isbn], shortcuts[:volume], shortcuts[:year])
    if ReferentMatch.match?(co.referent, rft.to_context_object.referent)
      return rft
    else
      return nil
    end
  end

  # When provided an OpenURL::ContextObject, it will return a Referent object
  # (creating one if doesn't already exist)  
  def self.find_or_create_by_context_object(co)
    # Okay, we need to do some pre-processing on weird context objects
    # sent by, for example, firstSearch.
    self.clean_up_context_object(co)
    
    if rft = Referent.find_by_context_object(co) 
      return rft
    else
      rft = Referent.create_by_context_object(co)
      return rft
    end
  end

  def self.create_by_context_object(co)
    self.clean_up_context_object(co)
    
    rft = Referent.new
    rft.save!
    
    rft.set_values_from_context_object(co)
    permalink = Permalink.new
    permalink.referent = rft
    permalink.save!
    
    val = ReferentValue.new
    val.key_name = 'identifier'
    val.value = permalink.tag_uri
    val.normalized_value = permalink.tag_uri
    rft.referent_values << val
    rft.referent_values.each do | val |
      rft.atitle = val.normalized_value if val.key_name == 'atitle' and val.metadata?
      rft.title = val.normalized_value if val.key_name.match(/^[bj]?title$/) and val.metadata? 
      rft.issn = val.normalized_value if val.key_name == 'issn' and val.metadata?
      rft.isbn = val.normalized_value if val.key_name == 'isbn' and val.metadata?      
      rft.volume = val.normalized_value if val.key_name == 'volume' and val.metadata?
      rft.year = val.normalized_value if val.key_name == 'date' and val.metadata?
    end
    rft.save!
    return rft          
  end

  # Okay, we need to do some pre-processing on weird context objects
  # sent by, for example, firstSearch. Remove invalid identifiers.
  # Mutator: Modifies ContextObject arg passed in. 
  def self.clean_up_context_object(co)
    # First, remove any empty DOIs! or other empty identifiers?
    # LOTS of sources send awful empty identifiers. 
    # That's not a valid identifier!
    empty_ids = co.referent.identifiers.find_all { |i| i =~ Regexp.new('^[^:]+:[^/]*/?$')}
    empty_ids.each { |e| co.referent.delete_identifier( e )}
    # Now look for ISSN identifiers that are on article_level. FirstSearch
    # gives us ISSN identifiers incorrectly on article level cites. 
    issn_ids = co.referent.identifiers.find_all { |i| i =~ /^urn:ISSN/}
    issn_ids.each do |issn_id|
      # Long as we're at it, add an rft.issn if one's not there.
      issn_data = issn_id.slice( (9..issn_id.length)) # actual ISSN without identifier prefix
      co.referent.set_metadata(issn, issn_data) if co.referent.get_metadata('issn').blank? && ! issn_data.blank?

      # And remove it as an identifier unless we know this is journal-level
      # cite.
      unless ( co.referent.get_metadata('genre') == 'journal' )
        co.referent.delete_identifier( issn_id )
      end      
    end    
  end

  
  # Populate the referent_values table with a ropenurl contextobject object
  def set_values_from_context_object(co)    
    rft = co.referent

    # Multiple identifiers are possible! 
    rft.identifiers.each do |id_string|
      id = ReferentValue.find_or_create_by_referent_id_and_key_name_and_value(self.id,'identifier',id_string)
      id.normalized_value = id_string if id.normalized_value.blank?
      id.save!
    end
    if rft.format
      fmt = ReferentValue.find_or_create_by_referent_id_and_key_name_and_value(self.id,'format',rft.format)
      fmt.normalized_value = ReferentValue.normalize(rft.format) if fmt.normalized_value.blank?
      fmt.save!
    end    
    
    rft.metadata.each_key { | key |
      next unless rft.metadata[key]
      rft_key = ReferentValue.find_or_create_by_referent_id_and_key_name_and_value(self.id,key,rft.metadata[key])
      rft_key.normalized_value =    
        ReferentValue.normalize(rft.metadata[key]) if rft_key.normalized_value.blank?
      rft_key.metadata = true
      rft_key.save!
    }
  end



  # Creates a hash of values from referrent_values, to assemble what was
  # spread accross differnet db rows into one easy-lookup hash, for
  # easy access. See also #to_citation for a different hash, specifically
  # for use in View to print citation. And #to_context_object. 
  def metadata
    self.referent_values
    metadata = {}
    self.referent_values.each { | val |
      metadata[val.key_name] = val.value if val.metadata? and not val.private_data?
    }
    return metadata
  end
  
  def private_data
    self.referent_values
    priv_data = {}
    self.referent_values.each { | val |
      priv_data[val.key_name] = val.value if val.private_data?
    }
    return priv_data    
  end
  
  def identifiers
    self.referent_values
    identifiers = []
    self.referent_values.each { | val |    
      if val.key_name == 'identifier'
        identifiers << val.value
      end
    }
    return identifiers
  end
  
  def format
    self.referent_values
    self.referent_values.each { | val |    
      if val.key_name == 'format'
        return val.value
      end
    }    
  end

  
  # Creates an OpenURL::ContextObject assembling all the data in this
  # referrent. 
  def to_context_object
    co = OpenURL::ContextObject.new
    rft = co.referent
    self.referent_values.each do | val |
      next if val.private_data?
      if val.metadata?
        rft.set_metadata(val.key_name, val.value)
        next
      end
      rft.send('set_'+val.key_name, val.value) if rft.respond_to?('set_'+val.key_name)        
    end
    return co
  end

  # Creates a hash for use in View code to display a citation
  def to_citation
    citation = {}
    if self.metadata['atitle']
      citation[:title] = self.metadata['atitle']
      citation[:title_label], citation[:subtitle_label] = 
        case self.metadata['genre']
          when /article|journal|issue/ then ['Article Title', 'Journal Title']
          when /bookitem|book/ then ['Chapter/Part Title', 'Book Title']
		      when /proceeding|conference/ then ['Proceeding Title', 'Conference Name']
		      when 'report' then ['Report Title','Report']    
		      else
		        if self.format == 'book'
              ['Chapter/Part Title', 'Title']
            elsif self.format == 'journal'
              ['Article Title', 'Journal Title']
            else # default fall through, use much what SFX uses. 
              ['Title', 'Source']
            end
        end
      ['title','btitle','jtitle'].each do | t_type |
        if self.metadata[t_type]
          citation[:subtitle] = self.metadata[t_type]
          break
        end
      end
    else      
      citation[:title_label] = case self.metadata["genre"]
  		when /article|journal|issue/ then 'Journal Title'
  		when /bookitem|book/ then 'Book Title'
  		when /proceeding|conference/ then 'Conference Name'
  		when 'report' then 'Report Title'
  		when nil then 'Title'
      end
      ['title','btitle','jtitle'].each do | t_type |
        if self.metadata[t_type]
          citation[:title] = self.metadata[t_type]
          break
        end
      end      
    end
    # add publisher for books
    if (self.metadata['genre'] == 'book')
      citation[:pub] = self.metadata['pub'] unless self.metadata['pub'].blank?
    end
    
    ['issn','isbn','volume','issue','date'].each do | key |
      citation[key.to_sym] = self.metadata[key]
    end
    if self.metadata["au"]
      citation[:author] = self.metadata["au"]
    elsif self.metadata["aulast"]
      citation[:author] = self.metadata["aulast"]
      if self.metadata["aufirst"]
   		citation[:author] += ',	'+self.metadata["aufirst"]
      else
        if self.metadata["auinit"]
          citation[:author] += ',	'+self.metadata["auinit"]
        else
		  if self.metadata["auinit1"]
            citation[:author] += ',	'+self.metadata["auinit1"]
   		  end
       	  if self.metadata["auinitm"]
            citation[:author] += self.metadata["auinitm"]
   		  end
   	    end
   	  end
   	end 
   	if self.metadata['spage']
   	  citation[:page] = self.metadata['spage']
   	  citation[:page] += ' - ' + self.metadata['epage'] if self.metadata['epage']
   	end
   	citation[:identifiers] = []
   	self.identifiers.each do | id |
   	  citation[:identifiers] << id unless id.match(/^tag:/)
   	end
   	return citation
  end
  
  def enhance_referent(key, value, metadata=true, private_data=false)
    return if value.nil?
    
    match = false
    unless metadata      
      match = self.referent_values.find(:all, :conditions=>['key_name = ? AND value = ?', key, value])
    else
      self.referent_values.find(:all, :conditions=>['key_name = ?', key]).each do | val |
        match = true
        next unless val.metadata?
        unless val.value == value
          val.value = value
          val.save
        end          
      end      
    end    
    unless match
      val = self.referent_values.create(:key_name => key, :value => value, :normalized_value => ReferentValue.normalize(value), :metadata => metadata, :private_data => private_data)
      val.save
    end 
    if key.match((/(^[ajb]?title$)|(^is[sb]n$)|(^volume$)|(^date$)/))
      case key
        when 'date' then self.year = ReferentValue.normalize(value)
        when 'volume' then self.volume = ReferentValue.normalize(value)
        when 'issn' then self.issn = ReferentValue.normalize(value)
        when 'isbn' then self.isbn = ReferentValue.normalize(value)
        when 'atitle' then self.atitle = ReferentValue.normalize(value)
        else self.title = ReferentValue.normalize(value)
      end
      self.save
    end
  end  
end
