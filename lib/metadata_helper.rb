# Helper class to get keyword searchable terms from OpenURL author and title
#
# OpenURLs have some commonly agreed upon metadata elements. This module is
# meant to help simplify things by sorting through the metadata and extracting
# what we need in a simpler interface. These values are specifically constructed
# from the citation to work well as keyword searches in other services.
#
# Also includes some helpful methods for getting identifiers out in a convenient to work with way, regardless of non-standard ways they may have been stored. 

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
      
    # Well, if we don't know the format and we do have a title use that.  
    # This might happen if we only have an ISBN to start and then enhance.
    # So should services like Amazon also enhance with a format, should
    # we simplify this method to not worry about format so much, or do we
    # keep this as is?
    elsif metadata['btitle']
      title = metadata['btitle']
    elsif metadata['title']
      title = metadata['title']
    end

    # Sometimes you have no title at all
    return nil if title.blank?

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

    return nil if title.blank?    


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

    return nil if creator.blank?
    
    return creator
  end

  # oclcnum, lccn, and isbn are both _supposed_ to be stored as identifiers
  # with an info: uri. info:oclcnum/#, info:lccn/#. But SFX sometimes stores
  # them in the referent metadata instead: rft.lccn, rft.oclcnum. .
  #
  # On the other hand, isbn and issn can legitimately be included in referent
  # metadata or as a urn. 
  #
  # This method will find you an identifier accross multiple places.
  #
  # type:  :urn or :info
  # subscheme: "lccn", "oclcnum", "isbn", "issn", or anything else that could be found in either a urn an info uri or a referent metadata.
  # referent: an umlaut Referent object
  #
  # returns nil if no identifier found, otherwise the bare identifier (not formatted into a urn/uri right now. Option should be maybe be added?) 
  def get_identifier(type, sub_scheme, referent )
    raise Exception.new("type must be :urn or :info") unless type == :urn or type == :info

    prefix = case type
               when :info : "info:#{sub_scheme}/"
               when :urn : "urn:#{sub_scheme}:"
             end
    
    bare_identifier = nil
    if (referent.identifiers.find {|id| id =~ /^#{prefix}(.*)/})
      # Pull it out of our regexp match
      bare_identifier = $1
    elsif (['lccn', 'oclcnum', 'isbn', 'issn'].include?(sub_scheme))
      # try the referent metadata
      bare_identifier = referent.metadata[sub_scheme]
    end

    
    return bare_identifier.blank? ? nil : bare_identifier
    
    
  end

  # finds and normalizes an LCCN. If multiple LCCNs are in the record,
  # returns the first one. 
  def get_lccn(rft)
    lccn = get_identifier(:info, "lccn", rft)
    
    lccn = normalize_lccn(lccn)
    
    return lccn
  end

  # Some normalization. See:
  # http://info-uri.info/registry/OAIHandler?verb=GetRecord&metadataPrefix=reg&identifier=info:lccn/
  # doesn't validate right now, only normalizes.
  # tbd, raise exception if invalid string. 
  def normalize_lccn(lccn)
    if ( lccn )
      # remove whitespace
      lccn = lccn.gsub(/\s/, '')
      # remove any forward slashes and anything after them
      lccn = lccn.sub(/\/.*$/, '')
      # pad anything after a hyphen before removing hyphen, if neccesary
      lccn = lccn.sub(/-(.*)/) do |match_str| 
        if $1.length < 6 
          ("0" * (6 - $1.length)) + $1 
        else
          $1
        end
      end
    end
    return lccn
  end
  
end
