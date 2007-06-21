class CiteulikeClient
  require 'uri'
  def make_interesting(link, context_object)  	
    unless self.title_match(link, context_object)
      return
    end
    return {:oai_target => {:repository=>"citeulike", :identifier=>link[:url]}}
  end
  def title_match(link, context_object)
    if link[:url].match(/\/article\/[0-9]*/)
      unless context_object.referent.metadata.has_key?("atitle")
        return false
      end
      if link[:title].downcase.strip == "citeulike: "+context_object.referent.metadata["atitle"].downcase
        return true
      elsif link[:title].downcase.match(context_object.referent.metadata["atitle"].downcase)
        return true
      elsif link[:title].gsub(/<.*?>/, '').strip.match(/\.\.\.$/)
        adj_title = link[:title].strip.downcase.sub(/citeulike:\s*/, '').gsub(/<.*?>/, '')
        adj_title.sub!(/\.\.\.$/, '')
        puts adj_title
        if context_object.referent.metadata["atitle"].downcase.match(Regexp.escape(adj_title))
          return true
        end
      end
    end
    if URI.parse(link[:url]).path.match(/^\/journal\//)
      return true
    end
    return false
  end
end

class CiteulikeOAIClient
  attr_reader :identifier, :label
  def initialize(provider, identifier)
    @provider = provider    
    @identifier = identifier.gsub(/\/user\/[A-z0-9_\-]*\/article\//, '/rss/article/')
    @identifier.gsub!(/\.org\/journal\//, '.org/rss/journal/')
    @label = 'CiteULike'
    @cul_host = 'http://www.citeulike.org/'
  end
  
	def do_request
	 puts self.class
		cul_uri = URI.parse(@identifier)
		http = Net::HTTP.new cul_uri.host
		http.open_timeout = 5
		http.read_timeout = 5
		begin 
			response = http.get(cul_uri.path)
		rescue  Timeout::Error
			return false
		end
		unless response.code == "200"
			return false
		end		
		return {:rss=>REXML::Document.new(response.body)}
	end
	
	def parse_response(response, metadataPrefix, record)
    if URI.parse(@identifier).path.match(/\/rss\/article\//)
      self.parse_article_response(response, metadataPrefix, record)
    elsif URI.parse(@identifier).path.match(/\/rss\/journal\//)      
      self.parse_journal_response(response, metadataPrefix, record)
    end
	end
	def parse_article_response(response, metadataPrefix, record)

		REXML::XPath.each(record, '/rdf:RDF/item/category', {'rdf'=>'http://www.w3.org/1999/02/22-rdf-syntax-ns#'}) { | cat |
			unless response.subjects.has_key?(:CiteULike)
				response.subjects[:CiteULike] = []
			end
			response.subjects[:CiteULike] << cat.get_text.value
		}
		if record.elements['/rdf:RDF/item/description']
		  description = {:source => 'CiteULike',
        :url => record.elements['/rdf:RDF/item/link'].get_text.value,          
        :content => record.elements['/rdf:RDF/item/description'].get_text.value}
			unless response.description.index(description)
			 response.description << description
			end
    end 
	end
	
	def parse_journal_response(response, metadataPrefix, record)
		REXML::XPath.each(record, "/rdf:RDF/item", {'rdf'=>'http://www.w3.org/1999/02/22-rdf-syntax-ns#'}) { | item |
			if item.elements['link'].get_text.value == @identifier
				next
			end

			format = nil
			identifier = nil
			description = nil			
			metadata = {}
			title = item.elements['dc:title'].get_text.value
			if item.elements['dc:identifier']
				identifier = item.elements['dc:identifier'].get_text.value
				format = 'journal'
				metadata[:genre] = 'article'
			end
			if item.elements['description']
				description = item.elements['description'].get_text.value
			end
			if item.elements['prism:publicationName']
				metadata[:jtitle] = item.elements['prism:publicationName'].get_text.value
				format = 'journal'
			end
			if item.elements['dc:creator']
				author = []
				item.elements.each('dc:creator') { | creator |
					author << creator.get_text.value
				}
				metadata[:author] = author[0]
			end
			if item.elements['prism:issn']
				metadata[:issn] = item.elements['prism:issn'].get_text.value
				format = 'journal'
			end
			
			if item.elements['prism:volume']
				metadata[:volume] = item.elements['prism:volume'].get_text.value
			end
			if item.elements['prism:number']
				metadata[:issue] = item.elements['prism:number'].get_text.value
			end			
			if item.elements['prism:startingPage']
				metadata[:spage] = item.elements['prism:startingPage'].get_text.value
			end		
			if item.elements['prism:endingPage']
				metadata[:epage] = item.elements['prism:endingPage'].get_text.value
			end		
			
			if format						
				ctx_object = OpenURL::ContextObject.new
				ctx_object.referent.set_format(format)				
				if identifier
					ctx_object.referent.set_identifier(identifier)
				end
				ctx_object.referent.set_metadata('atitle', title)
				metadata.each_key { | key |
					ctx_object.referent.set_metadata(key.to_s, metadata[key].to_s)
				}
				response.table_of_contents << ctx_object
			end
		}	
	end
	
	def extended_services(context_object, response)
		unless response.subjects[:CiteULike]
			return
		end
		query_path = '/rss/search/all?f=tag&q='
		query_path += response.subjects[:CiteULike].join("%20or%20")
		http = Net::HTTP.new URI.parse(@cul_host).host
		http.open_timeout = 5
		http.read_timeout = 5
		begin 
			resp = http.get(query_path)
		rescue  Timeout::Error
			return false
		end
		unless resp.code == "200"
			return false
		end	
		results = REXML::Document.new resp.body			
		REXML::XPath.each(results, "/rdf:RDF/item", {'rdf'=>'http://www.w3.org/1999/02/22-rdf-syntax-ns#'}) { | item |
			if item.elements['link'].get_text.value == @identifier
				next
			end
			unless response.similar_items.has_key?("OAI:citeulike".to_sym)
				response.similar_items["OAI:citeulike".to_sym] = []
			end
			format = nil
			identifier = nil
			description = nil			
			metadata = {}
			title = item.elements['dc:title'].get_text.value
			if item.elements['dc:identifier']
				identifier = item.elements['dc:identifier'].get_text.value
				format = 'journal'
				metadata[:genre] = 'article'
			end
			if item.elements['description']
				description = item.elements['description'].get_text.value
			end
			if item.elements['prism:publicationName']
				metadata[:jtitle] = item.elements['prism:publicationName'].get_text.value
				format = 'journal'
			end
			if item.elements['dc:creator']
				author = []
				item.elements.each('dc:creator') { | creator |
					author << creator.get_text.value
				}
				metadata[:author] = author[0]
			end
			if item.elements['prism:issn']
				metadata[:issn] = item.elements['prism:issn'].get_text.value
				format = 'journal'
			end
			
			if item.elements['prism:volume']
				metadata[:volume] = item.elements['prism:volume'].get_text.value
			end
			if item.elements['prism:number']
				metadata[:issue] = item.elements['prism:number'].get_text.value
			end			
			if item.elements['prism:startingPage']
				metadata[:spage] = item.elements['prism:startingPage'].get_text.value
			end		
			if item.elements['prism:endingPage']
				metadata[:epage] = item.elements['prism:endingPage'].get_text.value
			end		
			similar_item = {:title=>title, :description=>description, :url=>item.elements['link'].get_text.value}	
			if format						
				ctx_object = OpenURL::ContextObject.new
				ctx_object.referent.set_format(format)				
				if identifier
					ctx_object.referent.set_identifier(identifier)
				end
				ctx_object.referent.set_metadata('atitle', title)
				metadata.each_key { | key |
					ctx_object.referent.set_metadata(key.to_s, metadata[key].to_s)
				}
				similar_item[:context_object]=ctx_object
			end
			response.similar_items["OAI:citeulike".to_sym] << similar_item
			if response.similar_items["OAI:citeulike".to_sym].length == 10
				break
			end
		}
	end
end