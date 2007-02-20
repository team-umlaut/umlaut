class Pubmed < Service
  # This model will query the Pubmed eutils service to enhance the request
  # metadata
  require 'uri'
  require 'net/http'
  attr_reader :description,:subjects,:issn,:eissn,:volume,:issue,:date,:jtitle,:stitle,:atitle,:pages,:aulast,:aufirst,:auinit
  
  def handler(request)
    return true unless id = self.can_resolve?(request)
    return false unless response = self.fetch_record(id)
    self.parse_record(response)
    self.enhance_request(request)
  end
  
  # Only request for things with PMIDs
  def can_resolve?(req)
    id = nil
    req.referent_values.each { | val |
      id = val.value if val.key_name == 'identifier'
    }
    return unless id
    # PMIDs can come in with either of these prefixes
    if id.match(/^(info:pmid\/)|(pmid:)/)
      return id
    else 
      return false
    end
  end
  
  # Do the request.  Takes the PMID as inputs 
  def fetch_record(id)    
    id.sub!(/^(info:pmid\/)|(pmid:)/, "")
    pmid_url = self.url + "?db=pubmed&retmode=xml&rettype=full&id="+id
    begin
      response = Net::HTTP.get_response(URI.parse(pmid_url+id))
    rescue
      return false
    end
    return false if response.body.match("<ERROR>Empty id list - nothing todo</ERROR>")
    begin
      doc = REXML::Document.new response.body
      return doc
    rescue REXML::ParseException
      return false
    end
  end    
  
  # Pull everything useful out of the Pubmed record
  def parse_record(doc)    
    return unless cite = doc.elements["/PubmedArticleSet/PubmedArticle/MedlineCitation"] # Nothing of interest here
    
    # Get the MeSH subject headings
    @subjects = []
    cite.each_element('/MeshHeadingList/MeshHeading') { | mesh |
      subjects = []
      major = ''
      if dn = mesh.elements['DescriptorName']
        subjects << dn.get_text.value
        major = '*' if dn.attributes['MajorTopicYN'] == "Y"                      
      end
      if qn = mesh.elements['QualifierName']
        subjects << qn.get_text.value
        major = '*' if qn.attributes['MajorTopicYN'] == "Y"                      
      end  
      @subjects << subjects.join("/")+major        
    }
    return unless article = cite.elements["Article"] # No more useful metadata   
    @description = abstract.get_text.value if abstract = article.elements["/Abstract/AbstractText"] and abstract.has_text?
    
    if journal = query.elements['Journal']      
      context_object = {}
      valid_keys = ['format','genre','issn','eissn','volume','issue','date','jtitle','stitle','atitle','pages','aulast','aufirst','auinit']
      request.referent_values.each { | rft |
        context_object[rft.key_name.to_sym] = rft.value if valid_keys.index(rft.key_name)
      }

      if journal.elements['ISSN']
        if journal.elements['ISSN'].attributes['IssnType']=="Print"
          
          context_object_entity.set_metadata('issn', journal.elements['ISSN'].get_text.value)
        else 
          context_object_entity.set_metadata('eissn', journal.elements['ISSN'].get_text.value)
        end
      end
      if journal.elements['JournalIssue']
        if journal.elements['JournalIssue/Volume']
          context_object_entity.set_metadata('volume', journal.elements['JournalIssue/Volume'].get_text.value)
        end
        if journal.elements['JournalIssue/Issue']
          context_object_entity.set_metadata('issue', journal.elements['JournalIssue/Issue'].get_text.value)
        end   
        if journal.elements['JournalIssue/PubDate']
          if journal.elements['JournalIssue/PubDate/Year']
            context_object_entity.set_metadata('date', journal.elements['JournalIssue/PubDate/Year'].get_text.value)
          end
        end              
      end
      
      if journal.elements['Title']
        context_object_entity.set_metadata('jtitle', journal.elements['Title'].get_text.value)          
      end
      if journal.elements['ISOAbbreviation']
        context_object_entity.set_metadata('stitle', journal.elements['ISOAbbreviation'].get_text.value)
      end         
      if query.elements['ArticleTitle']
        context_object_entity.set_metadata('atitle', query.elements['ArticleTitle'].get_text.value)
      end   
      
      if query.elements['Pagination/MedlinePgn']
        context_object_entity.set_metadata('pages', query.elements['Pagination/MedlinePgn'].get_text.value)        
      end                

      if query.elements['AuthorList/Author']
        if query.elements['AuthorList/Author/LastName']
          context_object_entity.set_metadata('aulast', query.elements['AuthorList/Author/LastName'].get_text.value)
        end
        if query.elements['AuthorList/Author/ForeName']
          context_object_entity.set_metadata('aufirst', query.elements['AuthorList/Author/ForeName'].get_text.value)
        end          
        if query.elements['AuthorList/Author/Initials']
          context_object_entity.set_metadata('auinit', query.elements['AuthorList/Author/Initials'].get_text.value)
        end          
      end   
     
    end      
  
  end

  def enhance_request(req)
      context_object_entity.set_format('journal')
      context_object_entity.set_metadata('genre','article')    
    #Subject.new({:request_id=>request.id, :service_id => self.id, :authority=>'MeSH', :term=""})
    #request.descriptions << Description.new({:service_id=>self.id, :request_id=>request.id, :description=>abstract.get_text.value})    
  end

end
