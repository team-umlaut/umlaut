class DissertationCatch < ReferentFilter
   include MetadataHelper

   # ISSNs taken from http://spotdocs.scholarsportal.info/display/sfxdocs/SFX+and+Dissertations
   @@da_issns = []
   @@da_issns << "00994375" # Microfilm abstracts
   @@da_issns << "00993123" # Dissertation abstracts
   @@da_issns << "0420073X" # Dissertation abstracts. B, The sciences and engineering
   @@da_issns << "00959154" # Dissertation abstracts. A, The humanities and social sciences
   @@da_issns << "04194209" # Dissertation abstracts. A, The humanities and social sciences
   @@da_issns << "04194217" # Dissertation abstracts. A, The humanities and social sciences
   @@da_issns << "03076075" # Dissertation abstracts international. C, European abstracts
   @@da_issns << "10427279" # Dissertation abstracts international. C, Worldwide
   @@da_issns << "00255106" # Masters abstracts
   @@da_issns << "08989095" # Masters abstracts international
   @@da_issns << "1086962X" # Dissertation summaries in mathematics
   @@da_issns << "10644687" # Dissertation abstracts ondisc
   @@da_issns << "03616657" # Comprehensive dissertation index. Supplement
   @@da_issns << "10869700" # Dissertation summaries in chemical engineering
   @@da_issns << "10869689" # Dissertation summaries in computer sciences
   @@da_issns << "10869697" # Dissertation summaries in electrical engineering
   @@da_issns << "10869670" # Dissertation summaries in mechanical engineering
   # plus one more we've been using
   @@da_issns << "00993123" # Dissertation Abstracts


   
  # input: Umlaut Referent object
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
      title = if metadata['atitle'].present?
        metadata['atitle']
      elsif metadata['title'].present?
        metadata['title']
      end
      referent.enhance_referent("btitle", title) if title.present?
      referent.enhance_referent("title", title, true, false, :overwrite => true) if title.present?

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
      referent.remove_value("pages")
    end

  end
  
end
