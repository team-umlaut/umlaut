# OpenURLs have some commonly agreed upon metadata elements. This module is 
# meant to help simplify things by sorting through the metadata and extracting
# what we need in a simpler interface. For services that have to conduct 
# searches based on this metadata this 

module MetadataHelper
  
  # method that accepts a referent to return hash of common metadata elements 
  # choosing the available element for the format and the best available for 
  # searching. Wrapper around the other methods.
  def get_search_terms(rft)
    raise TypeError unless rft.class == Referent
    title = get_title(rft)
    creator = get_creator(rft)    
    
    # returns a hash of values so that more keys can be added
    # and not break services that use this module
    return :title => title, :creator => creator
  end
  
  # chooses the best available title for the format
  def get_title(rft)
    raise TypeError unless rft.class == Referent
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
    if (rft.format == 'book')
      colon_index = title.index(':')
      title = title.slice( (0..colon_index-1)  ) if colon_index
    end
    return title
  end
  
  # chooses the best available creator for the format
  def get_creator(rft)
    raise TypeError unless rft.class == Referent
    # Just make one call to create metadata hash
    metadata = rft.metadata
    # Identify dc.creator query. Prefer aulast alone if available.
    creator = nil
    creator = metadata['aulast'] unless metadata['aulast'].blank?
    creator = metadata['au'] if creator.blank?
    return creator
  end
  
end
