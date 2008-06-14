# OpenURLs have some commonly agreed upon metadata elements. This module is 
# meant to help simplify things by sorting through the metadata and extracting
# what we need in a simpler interface. For services that have to conduct 
# searches based on this metadata this 

module MetadataHelper
  
  # method that accepts a referent to return hash of common metadata elements 
  # choosing the available element for the format and the best available for 
  # searching. Wrapper around the other methods.
  def get_search_terms(rft)
    title = get_search_title(rft)
    creator = get_search_creator(rft)    
    
    # returns a hash of values so that more keys can be added
    # and not break services that use this module
    return {:title => title, :creator => creator}
  end
  
  # chooses the best available title for the format
  def get_search_title(rft)
    # Just make one call to create metadata hash
    metadata = rft.metadata
    title = nil
    if rft.format == 'journal' && metadata['atitle']
      title = metadata['atitle']
    elsif rft.format == 'book'
      title = metadata['btitle'] unless metadata['btitle'].blank?
      title = metadata['title'] if title.blank?
    end

    return nil if title.blank?    
    # For books, strip off subtitle after and including a ':'. 
    # Reduce false negatives by stripping it. 
    #if (options[:super_normalize] == 'book')
    if (true)
      colon_index = title.index(':')
      title = title.slice( (0..colon_index-1)  ) if colon_index

      # Strip anything after a '(' too. 
      paren_index = title.index("(");
      title = title.slice( (0..paren_index-1)  ) if paren_index
  
      # In general, changing punctuation to spaces seems helpful for eliminating
      # false negatives. Not only "weird" punctuation like curly-quotes seems
      # to result in false negative, but even normal punctuation can. If it's
      # not a letter or number, let's get rid of it. This method may or may
      # not be entirely unicode safe, but initial experiments were satisfactory.
      title = title.chars.gsub(/[^\w\s]/, ' ').to_s
    end


    return title
  end
  
  # chooses the best available creator for the format
  def get_search_creator(rft)
    # Just make one call to create metadata hash
    metadata = rft.metadata
    # Identify dc.creator query. Prefer aulast alone if available.
    creator = nil
    creator = metadata['aulast'] unless metadata['aulast'].blank?
    creator = metadata['au'] if creator.blank?
    return creator
  end
  
end
