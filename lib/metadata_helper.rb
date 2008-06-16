# Helper class to get keyword searchable terms from OpenURL author and title
#
# OpenURLs have some commonly agreed upon metadata elements. This module is
# meant to help simplify things by sorting through the metadata and extracting
# what we need in a simpler interface. These values are specifically constructed
# from the citation to work well as keyword searches in other services.

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

      semicolon_index = title.index(';')
      title = title.slice( (0..semicolon_index-1)  ) if semicolon_index

      # Strip anything after a '(' too. 
      paren_index = title.index("(");
      title = title.slice( (0..paren_index-1)  ) if paren_index
  
      # In general, changing punctuation to spaces seems helpful for eliminating
      # false negatives. Not only "weird" punctuation like curly-quotes seems
      # to result in false negative, but even normal punctuation can. If it's
      # not a letter or number, let's get rid of it. This method may or may
      # not be entirely unicode safe, but initial experiments were satisfactory.
      # Some punctuation we'll want to keep (e.g. Uncle Tom's Cabin)
      title = title.chars.gsub(/[^\w\s']/, ' ').to_s
      
      # FIXME if the author's name is part of title, strip it out?
      # See Andersen's Fairy Tales. Stripping off names gets more hits.
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
    # FIXME if capital letters are next to each other should we insert a space?
    #   Should we assume capitals next to each other are initials?
    #   Maybe only if we use au? 
    #   Logic like this makes refactoring to use Referent.to_citation less useful.
    
    # FIXME strip out commas from creator if we use au?
    return creator
  end
  
end
