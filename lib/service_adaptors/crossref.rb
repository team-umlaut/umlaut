# FIXME This service is not working.
# For starters it needs the method service_types_generated()

class Crossref < Service
  #require 'open_url'
  attr_reader :url, :username, :password
  def handle(request)
    return request.dispatched(self, true) unless id = self.can_resolve?(request)
    return request.dispatched(self, true) if self.already_resolved?(id)
    unless request.dispatched?(self)
      return request.dispatched(self, false) unless response = self.resolve(id)
      self.parse_record(response, request)
      xref = CrossrefLookup.new(:doi=>id.sub(/^doi:/, "info:doi/"))
      xref.save
      return request.dispatched(self, true)
    end  
  end


  # Only request for things with DOIs
  def can_resolve?(req)    
    req.referent.referent_values.find(:all, :conditions=>['key_name = ?', 'identifier']).each do | val |
      # DOIs can come in with either of these prefixes
      return val.value if val.value.match(/^(info:doi\/)|(doi:)10/)
    end    
    return false
  end  
  
  def already_resolved?(id)
    if id.match(/^doi:/) 
      id.sub!(/^doi:/, "info:doi/")
    end  
    return CrossrefLookup.find_by_doi(id)  
  end
  
  # Grab response from Crossref's OpenURL resolver
  def resolve(id)
    context_object = OpenURL::ContextObject.new
    if id.match(/^doi:/) 
      id.sub!(/^doi:/, "info:doi/")
    end
    context_object.referent.set_identifier(id)  
    transport = OpenURL::Transport.new(self.url, context_object)
    if self.username
      transport.extra_args['pid'] = self.username+":"+self.password
    end
    transport.extra_args['noredirect']='true'
    puts context_object.kev
    begin
      transport.transport_inline
      puts transport.response
      return transport.response
    rescue Timeout::Error
      return false
    end
  end  
  
  # Enhance the referent with Crossref's metadata
  def parse_record(body, request)
    require 'hpricot'
    doc = Hpricot(body)
    query = (doc/"/crossref_result/query_result/body/query").first
    if query && query.attributes['status'] == 'resolved'
      case (query/'/doi').first.attributes['type']
        when "journal_article"          
          request.referent.enhance_referent('format', 'book', false, false)
          request.referent.enhance_referent('genre', 'article', true, false)          
        when "journal_title"
          request.referent.enhance_referent('format', 'journal', false, false)
          request.referent.enhance_referent('genre', 'journal', true, false)          
        when "journal_issue"
          request.referent.enhance_referent('format', 'journal', false, false)
          request.referent.enhance_referent('genre', 'issue', true, false)            
        when "journal_volume"
          request.referent.enhance_referent('format', 'journal', false, false)
        when "conference_title"
          request.referent.enhance_referent('format', 'journal', false, false)
          request.referent.enhance_referent('genre', 'conference', true, false)          
        when "conference_series"
          request.referent.enhance_referent('format', 'journal', false, false)
          request.referent.enhance_referent('genre', 'conference', true, false)          
        when "conference_paper"
          request.referent.enhance_referent('format', 'journal', false, false)
          request.referent.enhance_referent('genre', 'proceeding', true, false)          
        when "book_title"
          request.referent.enhance_referent('format', 'book', false, false)
          request.referent.enhance_referent('genre', 'book', true, false)                            
        when "book_series"
          request.referent.enhance_referent('format', 'book', false, false)
          request.referent.enhance_referent('genre', 'book', true, false)          
        when "book_content"
          request.referent.enhance_referent('format', 'book', false, false)
          request.referent.enhance_referent('genre', 'bookitem', true, false)          
        when "report-paper_title"
          request.referent.enhance_referent('format', 'book', false, false)
          request.referent.enhance_referent('genre', 'report', true, false)                                          
        when "report-paper_title"
          request.referent.enhance_referent('format', 'book', false, false)
          request.referent.enhance_referent('genre', 'report', true, false)                                       
        when "report-paper_content"
          request.referent.enhance_referent('format', 'book', false, false)
          request.referent.enhance_referent('genre', 'report', true, false)          
      end
      if (query/'/journal_title').first
        request.referent.enhance_referent('jtitle', (query/'/journal_title').first.inner_html, true, false)          
      end
      if (query/'/article_title').first
        request.referent.enhance_referent('atitle', (query/'/article_title').first.inner_html, true, false)          
      end   
        
      if (query/'/volume').first
        request.referent.enhance_referent('volume', (query/'/volume').first.inner_html, true, false)          
      end
      if (query/'/issue').first
        request.referent.enhance_referent('issue', (query/'/issue').first.inner_html, true, false)          
      end      
      if (query/'/first_page').first
        request.referent.enhance_referent('spage', (query/'/first_page').first.inner_html, true, false)          
      end        
      if (query/'/year').first
        request.referent.enhance_referent('date', (query/'/year').first.inner_html, true, false)          
      end    
      if (query/'/author').first
        request.referent.enhance_referent('au', (query/'/author').first.inner_html, true, false)          
      end   
      if (query/'/journal_abbreviation').first
        request.referent.enhance_referent('stitle', (query/'/journal_abbreviation').first.inner_html, true, false)          
      end     
      if (query/'/isbn').first
        request.referent.enhance_referent('isbn', (query/'/isbn').first.inner_html, true, false)          
      end        

      (query/'issn').each do | issn |
        field = case issn.attributes['type']
          when 'print' then 'issn'
          when 'electronic' then 'eissn'
          end                  
        unless issn.inner_html == '00000000'
          request.referent.enhance_referent(field, (query/'/issn').first.inner_html, true, false)          
        end        
      end
    end
  end  
end
