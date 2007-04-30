class OpencontentSearch < Service
  require 'md5'
  require 'sru'
  def handle(request)
    if request.referent.format == "journal" or request.referent.metadata['genre'] == 'proceeding'
      archive = "oaister"
    elsif request.referent.format == "book"
      archive = "oca-all"    
    else
      return request.dispatched(self, true)     
    end
    query = self.define_query(request.referent)
    puts query
  end
  
  def define_query(rft)
    metadata = rft.metadata    
    query = []
    if rft.format == 'journal' && metadata['atitle']
      title = metadata['atitle']
    elsif rft.format == 'book'
      if metadata['btitle']
        title = metadata['btitle']
      elsif metadata['title']
        title = metadata['title']
      else
        return false
      end
    else
      return false
    end 
    query << 'dc.title = "'+title+'"'
    if metadata['au']
      query << 'dc.creator = "'+metadata['au']+'"'      
    elsif metadata['aulast']
      query << 'dc.creator = "'+metadata['aulast']+'"'    
    end
    return query.join(" and ")
  end
  def do_query(db, query)
    client = SRU::Client.new(self.url+db)
  end
end