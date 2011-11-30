# FIXME This service is not working
# For starters it needs the method service_types_generated()

# This model will query the Pubmed eutils service to enhance the request
# metadata
class Pubmed < Service  
  require 'uri'
  require 'net/http'
  require 'nokogiri'
  
  include MetadataHelper
  
  def initialize(config)
    @display_name = "PubMed"
    @url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi'
    super(config)
  end
  
  def handle(request)
    return request.dispatched(self, true) unless pmid = get_pmid(request.referent)
        
    return request.dispatched(self, false) unless response = self.fetch_record(pmid)
    
    self.enhance_referent(response, request)
    
    return request.dispatched(self, true)    
  end
  
  def service_types_generated
    @service_types ||= [ServiceTypeValue["referent_enhance"]]
  end
    
  
  # Do the request.  Takes the PMID as inputs 
  def fetch_record(pmid)  
    pmid_url = self.url + "?db=pubmed&retmode=xml&rettype=full&id="+pmid
    begin
      response = Net::HTTP.get_response(URI.parse(pmid_url))
    rescue
      return false
    end
    return false if response.body.match("<ERROR>Empty id list - nothing todo</ERROR>")
    return response.body
  end    
  
  # Pull everything useful out of the Pubmed record
  def enhance_referent(body, request)   
    doc = Nokogiri::XML(body)
    return unless cite = doc.at("PubmedArticleSet/PubmedArticle/MedlineCitation") # Nothing of interest here
    
    return unless article = cite.at("Article") # No more useful metadata   
    if abstract = article.at("Abstract/AbstractText")
      request.add_service_response(        
      :service=>self,
      :display_text => "Abstract from #{@display_name}",
      :content => abstract.inner_text,
      :service_type_value => 'abstract') unless abstract.inner_text.blank?      
    end
    
    if journal = article.at("Journal")
      if issn = journal.at('ISSN')
        if issn.attributes['issntype']=="Print"                  
          request.referent.enhance_referent('issn', issn.inner_html)
        else 
          request.referent.enhance_referent('eissn', issn.inner_html)        
        end
      end
      if jrnlissue = journal.at('JournalIssue')
        if volume = jrnlissue.at('Volume')
          request.referent.enhance_referent('volume', volume.inner_text)
        end
        if issue = jrnlissue.at('Issue')
          request.referent.enhance_referent('issue', issue.inner_text)
        end   
        if date = jrnlissue.at('PubDate')          
          request.referent.enhance_referent('date', date.inner_text)
          
        end              
      end
      
      if jtitle = journal.at('Title')
        request.referent.enhance_referent('jtitle', jtitle.inner_text)          
      end
      if stitle = journal.at('ISOAbbreviation')
        request.referent.enhance_referent('stitle', stitle.inner_text)
      end       
      
      if atitle = article.at('ArticleTitle')
        request.referent.enhance_referent('atitle', atitle.inner_text)
      end   
      
      if pages = article.at('Pagination/MedlinePgn')
        page_str = pages.inner_text
        request.referent.enhance_referent('pages', page_str)
        if spage = page_str.split("-")[0]
          request.referent.enhance_referent('spage', spage.strip)
        end
      end                

      if author = article.at('AuthorList/Author')
        if last_name = author.at('LastName')
          request.referent.enhance_referent('aulast', last_name.inner_text)
        end
        if first_name = author.at('ForeName')
          request.referent.enhance_referent('aufirst', first_name.inner_text)
        end          
        if initials = author.at('Initials')
          request.referent.enhance_referent('auinit', initials.inner_text)
        end          
      end              
    end      
  
  end

end
