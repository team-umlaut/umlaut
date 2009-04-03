# Helper class to get keyword searchable terms from OpenURL author and title
#
# OpenURLs have some commonly agreed upon metadata elements. This module is
# meant to help simplify things by sorting through the metadata and extracting
# what we need in a simpler interface. These values are specifically constructed
# from the citation to work well as keyword searches in other services.
#
# Also includes some helpful methods for getting identifiers out in a convenient to work with way, regardless of non-standard ways they may have been stored. 

module MetadataHelper
  include MarcHelper # for strip gmd functionality
  
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


  # A utility method to 'normalize' a title, for use when trying to match a
  # title from one place with records in another database.
  # Does lowercasing and removing puncutation, but also stripping out
  # a bunch of other things that may result
  # in false negatives. Exactly how you want to do for best results depends
  # on the particular data you are working with, you need to experiment to see.
  # MANY options are offered, although defaults are somewhat sensible.
  # Much of this stuff especially takes account of titles that may have
  # been generated from mark.
  # Will never return the emtpy string, will sometimes return nil. 
  def normalize_title(arg_title, options = {})
    # default options
    options[:rstrip_parens] ||= true
    options[:remove_all_parens] ||= true
    options[:strip_gmd] ||= true
    options[:subtitle_on_semicolon] ||=false
    options[:remove_subtitle] ||= false
    options[:normalize_ampersand] ||= true
    options[:remove_punctuation] ||= true
    
    return nil if arg_title.nil?
    title = arg_title.clone
    
    return nil if title.blank?

    # Sometimes titles given in the OpenURL have some additional stuff
    # in parens at the end, that messes up the search and isn't really
    # part of the title. Eliminate!
    title.gsub!(/\([^)]*\)\s*$/, '') if options[:rstrip_parens]
    # Or, not even just at the end, but anywhere! 
    title.gsub!(/\([^)]*\)/, '') if options[:remove_all_parens]

    # Remove things in brackets, part of an AACR2 GMD that's made it in.
    # replace with ':' so we can keep track of the fact that everything
    # that came afterwards was a sub-title like thing. 
    title = strip_gmd(title) if options[:strip_gmd]
    
    # There seems to be some catoging/metadata disagreement about when to
    # use ';' for a subtitle instead of ':'. Normalize to ':'.
    # also normalize the first period, to a ':', even though it's kind of
    # different, still seperates the 'main' title from other parts. 
    title.sub!(/[\;\.]/, ':') if options[:subtitle_on_semicolon]

    
    title.sub!(/\:(.*)$/, '') if options[:remove_subtitle]
    
    # Change ampersands to 'and' for consistency, we see it both ways.
    title.gsub!(/\&/, ' and ') if options[:normalize_ampersand]
      
    # remove non-alphanumeric, excluding apostrophe
    title.gsub!(/[^\w\s\']/, ' ') if options[:remove_punctuation]

    # apostrophe not to space, just eat it.
    title.gsub!(/[\']/, '') if options[:remove_punctuation]

    # compress whitespace
    title.strip!
    title.gsub!(/\s+/, ' ')

    title.downcase!
    
    title = nil if title.blank?

    return title
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

    return normalize_title(title, :remove_all_parens => true,
                                   :subtitle_on_semicolon => true,
                                   :remove_subtitle => true,
                                   :remove_punctuation => true)
    
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
  def get_identifier(type, sub_scheme, referent, options = {} )
    options[:multiple] ||= false
    
    raise Exception.new("type must be :urn or :info") unless type == :urn or type == :info

    prefix = case type
               when :info : "info:#{sub_scheme}/"
               when :urn : "urn:#{sub_scheme}:"
             end
    
    bare_identifier = nil
    identifiers = referent.identifiers.collect {|id| $1 if id =~ /^#{prefix}(.*)/}.compact

    if ( identifiers.blank? &&  ['lccn', 'oclcnum', 'isbn', 'issn'].include?(sub_scheme) )
      # try the referent metadata
      from_rft = referent.metadata[sub_scheme]
      identifiers = [from_rft] unless from_rft.blank?
    end

    if ( options[:multiple])
      return identifiers
    elsif ( identifiers[0].blank? )
      return nil
    else
      return identifiers[0]
    end        
    
  end

  # finds and normalizes an LCCN. If multiple LCCNs are in the record,
  # returns the first one. 
  def get_lccn(rft)
    lccn = get_identifier(:info, "lccn", rft)
    
    lccn = normalize_lccn(lccn)
    
    return lccn
  end

  # Gets an ISSN, makes sure it's a valid ISSN or else returns nil.
  # So will return a valid ISSN (NOT empty string) or nil. 
  def get_issn(rft)
    issn = rft.metadata['issn']
    issn = nil unless issn =~ /\d{4}(-)?\d{3}(\d|X)/
    return issn
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

  def get_isbn(rft)
    return get_identifier(:urn, "isbn", rft)    
  end

  def get_oclcnum(rft)
    return get_identifier(:info, "oclcnum", rft)    
  end

  def get_doi(rft)
    return get_identifier(:info, "doi", rft)
  end

  def get_pmid(rft)
    return get_identifier(:info, "pmid", rft)
  end

  # Returns an array, possibly empty. 
  def get_gpo_item_nums(rft)
    # In a technically illegal but used by OCLC info:gpo uri
    ids = get_identifier(:info, "gpo", rft, :multiple => true)
    # Remove the uri part. 
    return ids.collect {|id| id.sub(/^info:gpo\//, '')  }
  end

  def get_sudoc(rft)
    # Don't forget to unescape the sudoc that was escaped to maek it a uri!
    
    # Option 1: In a technically illegal but oh well info:sudoc uri
    
    sudoc = get_identifier(:info, "sudoc", rft)
    sudoc = CGI.unescape(sudoc) if sudoc

    # Option 2: rsinger's purl for sudoc. http://dilettantes.code4lib.org/2009/03/a-uri-scheme-for-sudocs/    
    unless sudoc
      sudoc = rft.identifiers.collect {|id| $1 if id =~ /^http:\/\/purl.org\/NET\/sudoc\/(.*)$/}.compact.slice(0)
      sudoc = CGI.unescape(sudoc) if sudoc
    end

    return sudoc
  end
  
end
