class Referent < ActiveRecord::Base
  # Shortcuts are really used as retrieval keys to 'shortcut' matching
  # referent. They hold normalized value (use ReferentValue.normalize) or
  # empty string. Never nil. 
  @@shortcut_attributes = [:atitle, :title, :issn, :isbn, :volume, :year]
  has_many :requests
  has_many :referent_values
  has_many :permalinks

  def before_validation_on_create
    # shortcuts initialize to empty string, they should never be null.
    @@shortcut_attributes.each do |key|
      self[key] = "" if self[key].nil?
    end
  end
  
  # When provided an OpenURL::ContextObject, it will return a Referent object
  # (if one exists). At least that's the intent. 
  #This turns out to be a really
  # tricky task, identifying when two citations that may not match exactly
  # are the same citation. So this doesn't really work well--we err
  # on the side of missing existing matches, better than finding
  # a false match. So there are seldom matches found. A particular
  # problem is that when the Referent is enhanced by a service,
  # it will no longer match _itself_ as it came in! Oh well. 
  def self.find_by_context_object(co)
    
    rft = co.referent

    # First try to find by id. There could be several.
    
    rft.identifiers.each do | ident |
      rft_val = ReferentValue.find(:first,
                        :conditions=> { :key_name => 'identifier', :normalized_value => ident} )
          
      # Not sure why there'd ever be an rft_val with a blank referent, but there was. 
      if (rft_val && rft_val.referent && rft_val.referent.metadata_intersects?( rft ))            
        return rft_val.referent
      end      
    end
        
    # Else try to find by special indexed shortcut values. Create hash
    # of shortcuts. 
    
    # Preload values as empty, even if they aren't found in our
    # incoming referent--we want to find a match with them empty too, then! 
    shortcuts = {:atitle=>"", :title=>"", :issn=>"", :isbn=>"", :volume=>"", :year=>""}
    
    # Special handling of title
    incoming_title = rft.metadata['jtitle'] || rft.metadata['btitle'] || rft.metadata['title']
    # DC OpenURL is an array, not a single value. Grr. 
    incoming_title = incoming_title[0] if incoming_title.kind_of?(Array)
    shortcuts[:title] = ReferentValue.normalize(incoming_title) if incoming_title
    # Special handling of date/year, since we use year instead of date for
    # stored shortcut. 
    # I don't know why.
    shortcuts[:year] = rft.metadata['date'] if rft.metadata['date']

    # Other four. 
    [:atitle, :issn, :isbn, :volume].each do |att|
      shortcuts[att] = ReferentValue.normalize( rft.metadata[att.to_s]) if rft.metadata[ att.to_s ]
    end
    # Don't look up by shortcuts if they're ALL blank. That doesn't do us well.
    found_rft = nil
    found_rft = Referent.find(:first, :conditions => shortcuts) if  shortcuts.values.find {|v| ! v.empty?}
    if ( found_rft && found_rft.metadata_intersects?( rft ) )
      return found_rft
    end
    
    # found nothing?
    return nil
  end

  # When provided an OpenURL::ContextObject, it will return a Referent object
  # (creating one if doesn't already exist)  . At least that's the idea.
  # But see caveats at #find_by_context_object . Most of the time
  # this ends up creating a new Referent.
  # pass in referrer for source-specific referent munging. 
  def self.find_or_create_by_context_object(co, referrer)
    # Okay, we need to do some pre-processing on weird context objects
    # sent by, for example, firstSearch.
    self.clean_up_context_object(co)
    
    if rft = Referent.find_by_context_object(co) 
      return rft
    else
      rft = Referent.create_by_context_object(co, referrer)
      return rft
    end
  end

  # Does call save! on referent created.
  # :permalink => false if you already have a permalink and don't
  # need to create one. Caller should attach that permalink to this referent!
  def self.create_by_context_object(co, referrer, options = {})    
    
    self.clean_up_context_object(co)    
    rft = Referent.new

    # Wrap everything in a transaction for better efficiency, at least
    # with MySQL, I think. 
    
    Referent.transaction do
      
      rft.set_values_from_context_object(co)

      unless ( options[:permalink] == false)
        permalink = Permalink.new_with_values!(rft, referrer)            
      end
  
      # Add shortcuts.
      rft.referent_values.each do | val |
        rft.atitle = val.normalized_value if val.key_name == 'atitle' and val.metadata?
        rft.title = val.normalized_value if val.key_name.match(/^[bj]?title$/) and val.metadata? 
        rft.issn = val.normalized_value if val.key_name == 'issn' and val.metadata?
        rft.isbn = val.normalized_value if val.key_name == 'isbn' and val.metadata?      
        rft.volume = val.normalized_value if val.key_name == 'volume' and val.metadata?
        rft.year = val.normalized_value if val.key_name == 'date' and val.metadata?
      end
      rft.save!

      # Apply referent filters
      rfr_id = referrer ? referrer.identifier : ''
      rfr_id = '' if rfr_id.nil?
      AppConfig.param("referent_filters").each do |regexp, filter|
        if (regexp =~ rfr_id)
          filter.filter(rft) if filter.respond_to?(:filter)
        end
      end      
    end
    return rft          
  end

  # Okay, we need to do some pre-processing on weird context objects
  # sent by, for example, firstSearch. Remove invalid identifiers.
  # Also will adjust context objects according to configured
  # umlaut refernet filters (see config.app_config.referent_filters in
  # environment.rb )
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

    # Clean up OCLC numbers from old bad formats that may have snuck in to an info url incorrectly. # also delete preceding 0's
    oclcnum_ids = co.referent.identifiers.find_all { |i| i =~ /^info:oclcnum/}
    oclcnum_ids.each do |oclcnum_id|
      # FIXME Does this regex need "ocn" as well?
      if (oclcnum_id =~ /^info:oclcnum\/(ocm0*|\(OCoLC\)|ocl70*|0+)(.*)$/)
        # Delete the original, take out just the actual oclcnum, not
        # those old prefixes. or preceding 0s.
        co.referent.delete_identifier( oclcnum_id )
        co.referent.add_identifier("info:oclcnum/#{$2}")
      end
    end


    
    
  end


  # Find or create a ReferentValue object hanging off this
  # Referent, with given key name and value. key_name can
  # be 'identifier', 'format', or any metadata key.
  def ensure_value!(key_name, value)
     normalized_value = ReferentValue.normalize(value)
     
     rv = ReferentValue.find(:first, 
                       :conditions => { :referent_id => self.id,
                                        :key_name => key_name,
                                        :normalized_value => normalized_value })
      unless (rv)
        rv = ReferentValue.new
        rv.referent = self
        
        rv.key_name = key_name
        rv.value = value
        rv.normalized_value = normalized_value

        unless (key_name == "identifier" || key_name == "format")
          rv.metadata = true
        end

        rv.save!
      end
      return rv
  end
  
  # Populate the referent_values table with a ropenurl contextobject object
  def set_values_from_context_object(co)
    
    rft = co.referent

  
    # Multiple identifiers are possible! 
    rft.identifiers.each do |id_string|
      ensure_value!('identifier', id_string)            
    end
    if rft.format
      ensure_value!('format', rft.format)
    end
                      
    rft.metadata.each { | key, value |
      next unless value
      ensure_value!( key, value)      
    }    
  end

  # pass in a Referent, or a ropenurl ContextObjectEntity that has a metadata
  # method. Or really anything with a #metadata method returning openurl-style
  # keys and values.
  # Method returns true iff the keys in common to both metadata packages
  # have equal (==) values. 
  def metadata_intersects?(arg)
    
    # if it's empty, good enough. 
    return true unless arg
    
    intersect_keys = self.metadata.keys & arg.metadata.keys
    # Take out keys who's values are blank. If one is blank but not
    # both, we can still consider that a match. 
    intersect_keys.delete_if{ |k| self.metadata[k].blank? || arg.metadata[k].blank? }
    
    self_subset = self.metadata.reject{ |k, v| ! intersect_keys.include?(k) }
    arg_subset = arg.metadata.reject{ |k, v| ! intersect_keys.include?(k) }

    return self_subset == arg_subset    
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

    # Got to initialize the referent entity properly for our format.
    # OpenURL sucks, this is confusing, yes. 
    fmt_uri = 'info:ofi/fmt:xml:xsd:' + self.format
    co.referent = OpenURL::ContextObjectEntity.new_from_format( fmt_uri )
    rft = co.referent
    
    # Now set all the values. 
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
    # call self.metadata once and use the array for efficiency, don't
    # keep calling it. profiling shows it DOES make a difference. 
    my_metadata = self.metadata
    
    
    if my_metadata['atitle']
      citation[:title] = my_metadata['atitle']
      citation[:title_label], citation[:subtitle_label] = 
        case my_metadata['genre']
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
        if my_metadata[t_type]
          citation[:subtitle] = my_metadata[t_type]
          break
        end
      end
    else      
      citation[:title_label] = case my_metadata["genre"]
        when /article|journal|issue/ then 'Journal Title'
        when /bookitem|book/ then 'Book Title'
        when /proceeding|conference/ then 'Conference Name'
        when 'report' then 'Report Title'
        else'Title'
      end
      ['title','btitle','jtitle'].each do | t_type |
        if my_metadata[t_type]
          citation[:title] = my_metadata[t_type]
          break
        end
      end      
    end
    # add publisher for books
    if (my_metadata['genre'] == 'book')
      citation[:pub] = my_metadata['pub'] unless my_metadata['pub'].blank?
    end
    
    ['issn','isbn','volume','issue','date'].each do | key |
      citation[key.to_sym] = my_metadata[key]
    end
    if my_metadata["au"]
      citation[:author] = my_metadata["au"]
    elsif my_metadata["aulast"]
      citation[:author] = my_metadata["aulast"]
      if my_metadata["aufirst"]
   		citation[:author] += ',	'+my_metadata["aufirst"]
      else
        if my_metadata["auinit"]
          citation[:author] += ',	'+my_metadata["auinit"]
        else
		  if my_metadata["auinit1"]
            citation[:author] += ',	'+my_metadata["auinit1"]
   		  end
       	  if my_metadata["auinitm"]
            citation[:author] += my_metadata["auinitm"]
   		  end
   	    end
   	  end
   	end 
   	if my_metadata['spage']
   	  citation[:page] = my_metadata['spage']
   	  citation[:page] += ' - ' + my_metadata['epage'] if my_metadata['epage']
   	end
   	citation[:identifiers] = []
   	self.identifiers.each do | id |
   	  citation[:identifiers] << id unless id.match(/^tag:/)
   	end
   	return citation
  end

  def type_of_thing
    genre = self.metadata["genre"]
    genre = nil if genre =~ /^unknown$/i
    genre ||= "resource"

    genre = "book section" if genre =~ /^bookitem$/i

    return genre
  end

  def remove_value(key)
    referent_values.find(:all, :conditions=> ['key_name =?', key]).each do |rv|
      rv.destroy
    end    
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
