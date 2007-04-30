class ReferentMatch
  def self.match?(rft1, rft2)
	if rft1.metadata['issn'] or rft2.metadata['issn']
      return false unless rft1.metadata['issn'].to_s == rft2.metadata['issn'].to_s
	end
	if rft1.metadata['isbn'] or rft2.metadata['isbn']
      return false unless rft1.metadata['isbn'].to_s == rft2.metadata['isbn'].to_s        
	end
	['title', 'jtitle', 'btitle'].each do | title |	
      if rft1.metadata[title] and (rft2.metadata["title"] or rft2.metadata["jtitle"] or rft2.metadata["btitle"])
        title_check = case rft1.metadata[title].to_s
          when rft2.metadata['title'].to_s then true
          when rft2.metadata['jtitle'].to_s then true
          when rft2.metadata['btitle'].to_s then true
          else false
        end
        unless title_check
          return false
        end				
      end
	end
	if rft1.metadata['volume'] or rft2.metadata['volume']
      return false unless rft1.metadata['volume'].to_s == rft2.metadata['volume'].to_s
	end		
	if rft1.metadata['date'] or rft2.metadata['date']
      return false unless rft1.metadata['date'].to_s == rft2.metadata['date'].to_s
	end
	
	return false if (rft1.metadata['date'].nil? and rft1.metadata['volume'].nil? and rft1.metadata['artnum'].nil?) and (rft2.metadata['date'] or rft2.metadata['volume'] or rft2.metadata['artnum'])	
	
	if rft1.metadata['issue'] or rft2.metadata['issue']
      return false unless rft1.metadata['issue'].to_s == rft2.metadata['issue'].to_s        
	end			
	if rft1.metadata['artnum'] or rft2.metadata['artnum']
      return false unless rft1.metadata['artnum'].to_s == rft2.metadata['artnum'].to_s        
	end		
	if (rft1.metadata['author'] == rft2.metadata['author']) or (rft1.metadata['aulast'] == rft2.metadata['aulast'])
      return true
	end
	return true
  end  
end