class DissertationCatch < ReferentFilter
   include MetadataHelper

   @@da_issns = ['00959154', '00993123', '04194209', '04194217', '0420073X', '00993123', '10427279', '03076075']
   
  # input: ropenurl ContextObject
  # Is this a citation to a Dissertation Abstracts
  # issn, or do we otherwise think it's a dissertation citation? Then change
  # it to a dissertation citation. 
  def filter(referent)
    issn = get_identifier(:urn, "issn", referent)

    return unless issn
    
    # normalize removing hyphen
    issn.gsub!('-', '')
    
    if ( @@da_issns.find { |i| i == issn } )
      # || lc($jtitle) =~ /dissertation/i || lc($jtitle2) =~ /dissertation/i)

      referent.enhance_referent("genre", "dissertation")
  
      metadata = referent.metadata
      # Reset it's title to the dissertation title
      title = metadata['atitle'] || metadata['title']
      referent.enhance_referent("btitle", title)
      referent.enhance_referent("title", title, true, false, :overwrite => true)
      # Now erase titles that do not apply 
      referent.remove_value("atitle")
      referent.remove_value("jtitle")
      referent.remove_value("stitle")
      # issn or isbn are wrong, probably point to Dissertation Abstracts
      referent.remove_value("issn")
      referent.remove_value("isbn")
      # Same with all article level metadata
      referent.remove_value("volume")
      referent.remove_value("issue")
      referent.remove_value("issue_start")
      referent.remove_value("spage")
      referent.remove_value("epage")
    end

  end
  
end
