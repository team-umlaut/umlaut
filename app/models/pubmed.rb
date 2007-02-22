class Pubmed < Service
  # This model will query the Pubmed eutils service to enhance the request
  # metadata
  require 'uri'
  require 'net/http'
  attr_reader :description,:subjects,:issn,:eissn,:volume,:issue,:date,:jtitle,:stitle,:atitle,:pages,:aulast,:aufirst,:auinit
  
  def handle(request)
    return request.dispatched(self, true) unless id = self.can_resolve?(request)
    if request.dispatched?(self)
      self.load_from_request(request)
    else
      return request.dispatched(self, false) unless response = self.fetch_record(id)
      self.parse_record(response, request)
    end
  end
  
  def load_from_request(request)
    @subjects = {}
    request.service_responses.find(:all, :conditions=>["service_id = ?", self.id]).each do | resp |
      @description = resp.value if resp.key == 'description'
      if resp.key == 'subject'
        @subjects[resp.value2] = [] unless @subjects[resp.value2]
        @subjects[resp.value2] << resp.value
      end        
    end
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
      response = Net::HTTP.get_response(URI.parse(pmid_url))
    rescue
      return false
    end
    return false if response.body.match("<ERROR>Empty id list - nothing todo</ERROR>")
    #begin
    #  doc = REXML::Document.new response.body
    #  return doc
    #rescue REXML::ParseException
    #  return false
    #end
    return response.body
  end    
  
  # Pull everything useful out of the Pubmed record
  def parse_record(body, request)   
    require 'hpricot'
    doc = Hpricot(body)
    return unless cite = (doc/"/PubmedArticleSet/PubmedArticle/MedlineCitation") # Nothing of interest here
    
    # Get the MeSH subject headings
    @subjects = {}
    (cite/'/MeshHeadingList/MeshHeading').each do | mesh |
      @subjects["mesh"] = [] unless @subjects["mesh"]
      subjects = []
      major = ''
      (mesh/'DescriptorName').each do | dn |
        subjects << dn.get_text.value
        major = '*' if dn.attributes['MajorTopicYN'] == "Y"                      
      end
      if qn = mesh.elements['QualifierName']
        subjects << qn.get_text.value
        major = '*' if qn.attributes['MajorTopicYN'] == "Y"                      
      end  
      @subjects["mesh"] << subjects.join("/")+major 
      request.add_service_response({:service=>self,:key=>'subject',:value_string=>subjects.join("/")+major,:value_alt_string=>'mesh'}, ['subject'])             
    end
    
    return unless article = (cite/"Article") # No more useful metadata   
    @description = abstract.inner_html if abstract = (article/"/Abstract/AbstractText")
    request.add_service_response({:service=>self,:key=>'abstract',:value_text=>@description}, ['abstract']) unless @description.blank?
    if journal = (article/"journal")

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
