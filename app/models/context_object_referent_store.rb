class ContextObjectReferentStore
	require 'ferret'
	include Ferret
	
	def initialize
		@index = Index::Index.new(:path => RAILS_ROOT+'db/ferret/referents', :create => true)		
	end
	
	def find_by_context_object(context_object)
		rft = context_object.referent
		queries = case rft.format
			when 'book' then self.get_book_query(rft)
			when 'journal' then self.get_journal_query(rft)
			else self.get_unknown_query(rft)
		end
		queries << "format:"+rft.format
		unless rft.identifier.class == Array
			unless rft.identifier.nil?
				queries << 'identifier:"'+rft.identifier+'"'
			end
		else
			for id in rft.identifier 
				queries << 'identifier:"'+id+'"'
			end
		end
		results = []
		begin
		  puts queries.join(" ")
  		@index.search_each(queries.join(" ")) { | result, score |
  			results << result
  		}
	  rescue EOFError
	    return false
	  end  		
		if results.length == 0
			return false
		end
		unless results.length > 1
			return @index[results[0]]
		end
		return self.find_match(results, rft)
	end
	
	def find_by_id(request_id)
	  begin
	    return @index[request_id]	
	  rescue EOFError
	    return false
	  end
	end
	
	def get(id)
		return @index[id]
	end
	
	def save_to_store(context_object, referent)
		doc = self.find_by_id(referent.id.to_s)
		if doc
	 		@index.delete(referent.id.to_s)
		else
			doc = Document.new
		end
		rft = context_object.referent
		unless rft.identifier.class == Array
			unless rft.identifier.nil?
				unless self.in_doc?(doc, :identifier, rft.identifier)
					doc[:identifier] = Field.new(rft.identifier)
				end
			end
		else
		  rfts = nil
			for rft_id in rft.identifier 
				unless self.in_doc?(doc, :identifier, rft_id)
				  unless rfts
				    rfts = Field.new(rft_id)
				  else
				    rfts << rft_id	
				  end
				end
			end
			doc[:identifier] = rfts if rfts
		end	 
		unless self.in_doc?(doc, :format, rft.format)
			doc[:format] = Field.new(rft.format)
		end
		unless self.in_doc?(doc, :id, referent.id.to_s)		
			doc[:id] = Field.new(referent.id.to_s)
		end
		rft.metadata.each { | key, val| 
			unless val.class == Array
				unless self.in_doc?(doc, key.to_sym, val)
					doc[key.to_sym] = Field.new(val)
				end
			else
				self.step_through_array(doc, key, val)			
			end
		}
		subjects = {}
		referent.subjects.each { | subj |
		  unless subjects[subj.authority.to_sym]
		    subjects[subj.authority.to_sym] = Field.new(subj)
		  else
		    subjects[subj.authority.to_sym] << subj
		  end  		
		}	 
		unless subjects.empty?
		  subjects.keys.each { | authority |
		    doc[authority] = subjects[authority]
		  }
		end
		#@index << doc
		#@index.flush
	end
	
	def step_through_array(doc, key, val)
		val.each { | v |
			if v.class == Array
				self.step_through_keys(doc, key, v)
			elsif v.class == Hash
				self.step_through_hash(doc, v)
			else
				unless self.in_doc?(doc, key.to_sym, v)
				  if doc.fields.index(key.to_sym)
					  doc[key.to_sym] << v
					else
					  doc[key.to_sym] = Field.new(v)
					end
				end
			end
		}	
	end
	
	def step_through_hash(doc, hash)
		hash.each { |key, val|
			if val.class == Array
				self.step_through_array(doc, key, val)
			elsif val.class == Hash
				self.step_through_hash(doc, val)
			else
				unless self.in_doc?(doc, key.to_sym, val)
			    if doc.fields.index(key.to_sym)
					  doc[key.to_sym] << v
					else
					  doc[key.to_sym] = Field.new(v)
					end									
				end
			end
		}
	end
	
	def in_doc?(doc, key, val)
		unless doc.keys.index(key)
			return false
		end
		if doc[key].class == Array
  		doc[key].each { | field |
  			if field == val
  				return true
  			end
  		}
  	else
  	  if doc[key] == val
  	    return true
  	  else
  	    return false
  	  end
  	end
		return false
	end
	
	def get_book_query(rft)

		queries = []
		searchable_keys = ['atitle', 'aulast', 'author', 'isbn', 'date', 'volume', 'issue', 'spage', 'epage', 'pages', 'genre', 'edition']
		searchable_keys.each { | key |
			if rft.metadata.has_key?(key)
				unless rft.metadata[key].nil?
					queries << key+':'+self.escape_query(rft.metadata[key])
				end
			end
		}
		if rft.metadata.has_key?('title') or rft.metadata.has_key?('btitle')
			title = nil
			if rft.metadata.has_key?('btitle')
				unless rft.metadata['btitle'].nil?
					title = rft.metadata['btitle']
				end
			end
			if title.nil? and rft.metadata.has_key?('title')
				unless rft.metadata['title'].nil?
					title = rft.metadata['title']
				end
			end			
			unless title.nil?
				queries << 'btitle:'+self.escape_query(title)
				queries << 'title:'+self.escape_query(title)
			end
		end		
		return queries
	end
	
	def get_journal_query(rft)
		queries = []
		searchable_keys = ['atitle', 'aulast', 'author', 'issn', 'date', 'volume', 'issue', 'spage', 'epage', 'pages', 'artnum', 'eissn', 'isbn', 'coden', 'sici', 'genre', 'object_id']
		searchable_keys.each { | key |
			if rft.metadata.has_key?(key)
				unless rft.metadata[key].nil?
					queries << key+':'+self.escape_query(rft.metadata[key])
				end
			end
		}
		if rft.metadata.has_key?('title') or rft.metadata.has_key?('jtitle')
			title = nil
			if rft.metadata.has_key?('jtitle')
				unless rft.metadata['jtitle'].nil?
					title = rft.metadata['jtitle']
				end
			end
			if title.nil? and rft.metadata.has_key?('title')
				unless rft.metadata['title'].nil?
					title = rft.metadata['title']
				end
			end			
			unless title.nil?
				queries << 'jtitle:'+self.escape_query(title)
			end
		end		
		return queries
	end	
	
  def escape_query(str)
	  term = str.gsub(/\s-/,'\s')
	  #if term.match(/\s/)
    #  term.gsub!(/([\"\|])/, '\\\\\1')
    #  term.gsub!(/\<\>/, '<\\>')
    #  term = '"'+term.gsub(/\(\)/, '')+'"'
      
    #else 
      term.gsub!(/([\]\:\[\]\{\}\!\+\"\~\^\-\|\<\>\=\*\?\#])/, '\\\\\1')
    #end

	  return term  
  end
  
	def get_unknown_query(rft)

		queries = []
		searchable_keys = ['atitle', 'btitle', 'jtitle', 'aulast', 'author', 'issn', 'date', 'volume', 'issue', 'spage', 'epage', 'pages', 'title', 'genre']
		searchable_keys.each { | key |
			if rft.metadata.has_key?(key)
				unless rft.metadata[key].nil?
					queries << key+':'+self.escape_query(rft.metadata[key])
				end
			end
		}

		return queries
	end	
	
	def find_match(results, rft)
		match = nil
		results.each { | result |
			doc = @index[result]
			unless doc["identifier"].nil?
			  if doc[:identifier].class == Array
  				doc[:identifier].each { | id |
  					if id == rft.identifier
  						return doc
  					end
  				}
  			else 
  			  if doc[:identifier] == rft.identifier
  			    return doc
  			  end
  			end
			end
			unless doc[:atitle] == rft.metadata['atitle']
				next
			end			
			
			unless self.item_match?(doc, rft)
				next
			end			
			match = doc
			break
		}
		if match.nil?
			return false
		end

		return match					
	end	
	
	def item_match?(doc, rft)
		if rft.metadata['issn'] and doc[:issn]
			unless rft.metadata['issn'] == doc[:issn]
				return false
			end
		end
		if rft.metadata['isbn'] and doc[:isbn]
			unless rft.metadata['isbn'] == doc[:isbn]
				return false
			end
		end
		if doc[:title] and (rft.metadata["title"] or rft.metadata["jtitle"] or rft.metadata["btitle"])
			title_check = case doc[:title]
				when rft.metadata['title'] then true
				when rft.metadata['jtitle'] then true
				when rft.metadata['btitle'] then true
				else false
			end
			unless title_check
				return false
			end				
		end
		if rft.metadata['volume'] and doc[:volume]
			unless rft.metadata['volume'] == doc[:volume]
				return false
			end
		end		
		if rft.metadata['date'] and doc[:date]
			unless rft.metadata['date'] == doc[:date]
				return false
			end
		end	
		if rft.format == 'journal' and doc[:date] and (rft.metadata['date'].nil? and rft.metadata['volume'].nil? and rft.metadata['artnum'].nil? and rft.identifier.nil?)
		  return false
		end
		
		if rft.metadata['issue'] and doc[:issue]
			unless rft.metadata['issue'] == doc[:issue]
				return false
			end
		end			
		if rft.metadata['artnum'] and doc[:artnum]
			unless rft.metadata['artnum'] == doc[:artnum]
				return false
			end
		end		
		if (rft.metadata['author'] == doc[:author]) or (rft.metadata['aulast'] == doc[:aulast])
			return true
		end
		return true
	end
	

		
end