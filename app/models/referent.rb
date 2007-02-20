class Referent < ActiveRecord::Base
  has_many :requests
  has_many :referent_values
  has_many :permalinks
  
  # When provided an OpenURL::ContextObject, it will return a Referent object (if one exists)
  def self.find_by_context_object(co)
    rft = co.referent
    if id = rft.identifier
      id = [id] unless id.is_a?(Array)
      id.each do | ident |
        return rft_val.referent if rft_val = ReferentValue.find_by_key_name_and_normalized_value('identifier', ident.downcase)
      end
    end
    
    shortcuts = {:atitle=>nil, :title=>nil, :issn=>nil, :isbn=>nil, :volume=>nil, :year=>nil}    
    shortcuts[:atitle] = rft.metadata['atitle'].downcase[0..254] if rft.metadata['atitle']
    if rft.metadata['jtitle']
      shortcuts[:title] = rft.metadata['jtitle'].downcase[0..254]
    elsif rft.metadata['btitle']
      shortcuts[:title] = rft.metadata['btitle'].downcase[0..254]
    elsif rft.metadata['title']
      shortcuts[:title] = rft.metadata['title'].downcase[0..254]      
    end
    
    shortcuts[:issn] = rft.metadata['issn'].downcase if rft.metadata['issn']
    shortcuts[:isbn] = rft.metadata['isbn'].downcase if rft.metadata['isbn']    
    shortcuts[:volume] = rft.metadata['volume'].downcase if rft.metadata['volume']
    shortcuts[:year] = rft.metadata['date'].downcase if rft.metadata['date']

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
    if rft = Referent.find_by_context_object(co) 
      return rft 
    end
    rft = Referent.new
    rft.save
    rft.set_values_from_context_object(co)
    permalink = Permalink.new
    permalink.referent = rft
    permalink.save
    val = ReferentValue.new
    val.key_name = 'identifier'
    val.value = permalink.tag_uri
    val.normalized_value = permalink.tag_uri
    rft.referent_values << val
    rft.referent_values.each do | val |
      rft.atitle = val.normalized_value if val.key_name == 'atitle' and val.metadata?
      rft.title = val.normalized_value if val.key_name.match(/title|btitle|jtitle/) and val.metadata? 
      rft.issn = val.normalized_value if val.key_name == 'issn' and val.metadata?
      rft.isbn = val.normalized_value if val.key_name == 'isbn' and val.metadata?      
      rft.volume = val.normalized_value if val.key_name == 'volume' and val.metadata?
      rft.year = val.normalized_value if val.key_name == 'date' and val.metadata?
    end
    rft.save
    return rft          
  end
  
  # Populate the referent_values table with a ropenurl contextobject object
  def set_values_from_context_object(co)
    rft = co.referent
    if rft.identifier
      id = ReferentValue.find_or_create_by_referent_id_and_key_name_and_value(self.id,'identifier',rft.identifier)
      id.normalized_value = rft.identifier unless id.normalized_value
      id.save
    end
    if rft.format
      fmt = ReferentValue.find_or_create_by_referent_id_and_key_name_and_value(self.id,'format',rft.format)
      fmt.normalized_value = rft.identifier unless fmt.normalized_value
      fmt.save
    end    
    
    rft.metadata.each_key { | key |
      next unless rft.metadata[key]
      rft_key = ReferentValue.find_or_create_by_referent_id_and_key_name_and_value(self.id,key,rft.metadata[key])
      rft_key.normalized_value = rft.metadata[key].downcase if rft_key.normalized_value = ""
      rft_key.metadata = true
      rft_key.save
    }
  end
   
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
end
