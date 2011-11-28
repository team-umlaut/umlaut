# FIXME This service is not working
# For starters it needs the method service_types_generated()

class Pubmed < Service
  # This model will query the Pubmed eutils service to enhance the request
  # metadata
  require 'uri'
  require 'net/http'
  attr_reader :description,:subjects,:issn,:eissn,:volume,:issue,:date,:jtitle,:stitle,:atitle,:pages,:aulast,:aufirst,:auinit
  
  def handle(request)
    return request.dispatched(self, true) unless id = self.can_resolve?(request)
    unless request.dispatched?(self)
      return request.dispatched(self, false) unless response = self.fetch_record(id)
      self.parse_record(response, request)
      return request.dispatched(self, true)
    end
  end
  
  # Only request for things with PMIDs
  def can_resolve?(req)    
    req.referent.referent_values.find(:all, :conditions=>['key_name = ?', 'identifier']).each do | val |
      # PMIDs can come in with either of these prefixes
      return val.value if val.value.match(/^(info:pmid\/)|(pmid:)/)          
    end    
    return false
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
    return response.body
  end    
  
  # Pull everything useful out of the Pubmed record
  def parse_record(body, request)   
    require 'hpricot'
    doc = Hpricot(body)
    return unless cite = (doc/"/PubmedArticleSet/PubmedArticle/MedlineCitation") # Nothing of interest here
    
    return unless article = (cite/"/Article").first # No more useful metadata   
    if abstract = (article/"/Abstract/AbstractText").first
      @description = abstract.inner_html 
    end
    request.add_service_response(
      :service=>self,
      :key=>'abstract',
      :value_text=>@description,
      :service_type_value => 'abstract') unless @description.blank?
    
    if journal = (article/"/journal").first
      if issn = (journal/'/ISSN').first
        if issn.attributes['issntype']=="Print"                  
          request.referent.enhance_referent('issn', issn.inner_html, true, false)
        else 
          request.referent.enhance_referent('eissn', issn.inner_html, true, false)        
        end
      end
      if jrnlissue = (journal/'/JournalIssue').first
        if (jrnlissue/'/Volume').first
          request.referent.enhance_referent('volume', (jrnlissue/'/Volume').first.inner_html, true, false)
        end
        if (jrnlissue/'/Issue').first
          request.referent.enhance_referent('issue', (jrnlissue/'/Issue').first.inner_html, true, false)
        end   
        if (jrnlissue/'/PubDate').first
          if (jrnlissue/'/PubDate/Year').first
            request.referent.enhance_referent('date', (jrnlissue/'/PubDate/Year').first.inner_html, true, false)
          end
        end              
      end
      
      if (journal/'/Title').first
        request.referent.enhance_referent('jtitle', (journal/'/Title').first.inner_html, true, false)          
      end
      if (journal/'/ISOAbbreviation').first
        request.referent.enhance_referent('stitle', (journal/'/ISOAbbreviation').first.inner_html, true, false)
      end         
      if (journal/'/ArticleTitle').first
        request.referent.enhance_referent('atitle', (journal/'/ArticleTitle').first.inner_html, true, false)
      end   
      
      if (article/'/Pagination/MedlinePgn').first
        request.referent.enhance_referent('pages', (article/'/Pagination/MedlinePgn').first.inner_html, true, false)        
      end                

      if (article/'/AuthorList/Author').first
        if (article/'/AuthorList/Author/LastName').first
          request.referent.enhance_referent('aulast', (article/'/AuthorList/Author/LastName').first.inner_html, true, false)
        end
        if (article/'/AuthorList/Author/ForeName').first
          request.referent.enhance_referent('aufirst', (article/'/AuthorList/Author/ForeName').first.inner_html, true, false)
        end          
        if (article/'AuthorList/Author/Initials').first
          request.referent.enhance_referent('auinit', (article/'AuthorList/Author/Initials').first.inner_html, true, false)
        end          
      end   
      request.referent.save
      request.save     
    end      
  
  end

end
