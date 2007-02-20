class ReferentMatch
  def self.match?(rft1, rft2)
	if rft1.metadata['issn'] or rft2.metadata['issn']
      unless rft1.metadata['issn'] == rft2.metadata['issn']
        return false
      end
	end
	if rft1.metadata['isbn'] or rft2.metadata['isbn']
      unless rft1.metadata['isbn'] == rft2.metadata['isbn']
        return false
      end
	end
	['title', 'jtitle', 'btitle'].each do | title |	
      if rft1.metadata[title] and (rft2.metadata["title"] or rft2.metadata["jtitle"] or rft2.metadata["btitle"])
        title_check = case rft1.metadata[title]
          when rft2.metadata['title'] then true
          when rft2.metadata['jtitle'] then true
          when rft2.metadata['btitle'] then true
          else false
        end
        unless title_check
          return false
        end				
      end
	end
	if rft1.metadata['volume'] or rft2.metadata['volume']
      unless rft1.metadata['volume'] == rft2.metadata['volume']
        return false
      end
	end		
	if rft1.metadata['date'] or rft2.metadata['date']
      unless rft1.metadata['date'] == rft2.metadata['date']
        return false
      end
	end
	
	return false if (rft1.metadata['date'].nil? and rft1.metadata['volume'].nil? and rft1.metadata['artnum'].nil?) and (rft2.metadata['date'] or rft2.metadata['volume'] or rft2.metadata['artnum'])	
	
	if rft1.metadata['issue'] or rft2.metadata['issue']
      unless rft1.metadata['issue'] == rft2.metadata['issue']
        return false
      end
	end			
	if rft1.metadata['artnum'] or rft2.metadata['artnum']
      unless rft1.metadata['artnum'] == rft2.metadata['artnum']
        return false
      end
	end		
	if (rft1.metadata['author'] == rft2.metadata['author']) or (rft1.metadata['aulast'] == rft2.metadata['aulast'])
      return true
	end
	return true
  end  
end