# A class that bundles up all the info that the Dispatcher can collect
class DispatchResponse
  attr_accessor :external_links, :similar_items, :subjects, :cover_art, :description, :highlighted_links, :service_responses, :relevant_links
  attr_accessor :print_locations, :fulltext_links, :table_of_contents, :related_titles, :document_delivery, :oai_targets, :dispatched_services
  
  require "rexml/document"
  require "uri"
  
  def initialize
    @external_links = {}
    @similar_items = {}
    @subjects = {}
    @cover_art = {}
    @description = []
    @highlighted_links = []
    @service_responses = {}
    @fulltext_links = []
    @print_locations = []
    @table_of_contents = []
    @related_titles = []
    @document_delivery = []
    @oai_targets = []
    @dispatched_services = {}
    @relevant_links = []
  end
  
  def add_to_fulltext_links(link_hash)    
    begin
      @fulltext_links.each { | ft |
      	if ft[:url] == link_hash[:url]
      		return
      	end
      	unless URI.parse(ft[:url]).host == "www.library.gatech.edu"
	        if URI.parse(ft[:url]).host == URI.parse(link_hash[:url]).host
  	        return
    	    end
 	    	 end
      	}
      
	      LinkResolver.find(:all).each { | lr |
  	      if URI.parse(lr.url).host == URI.parse(link_hash[:url]).host
    	      return
      	  end            
	      }

    rescue URI::InvalidURIError
    end
   
    @fulltext_links << link_hash    
  end
  
  def relevant_external_links(context_object)
    relevant_sites = self.load_relevant_sites
    irrelevant_sites = self.load_irrelevant_sites
    check_proxy = []
    relevant_results = []
    @external_links.each_key { | el |
    	unless @external_links[el].nil?
	      @external_links[el].each { |link|
	        begin
	          host = URI.parse(link[:url])
	          unless irrelevant_sites.index(host.host)
	            if relevant_sites.index(host.host)
	              relevant_results << link
	              if self.is_interesting?(host.host)                
	                if response = self.get_interesting_site(link, context_object)                    
	                  if response.has_key?(:highlighted_link)
	                    unless @highlighted_links.index(response[:highlighted_link])
	                      @highlighted_links << response[:highlighted_link]
	                    end
	                  end
	                  if response.has_key?(:oai_target)
	                    unless @oai_targets.index(response[:oai_target])
	                      @oai_targets << response[:oai_target]
	                    end
	                  end
	                  if response.has_key?(:fulltext_link)
	                    self.add_to_fulltext_links(response[:fulltext_link])                    
	                  end
	                end
	              end
	            else
	              check_proxy << link
	            end
	          end
	        rescue URI::InvalidURIError
	        end          
	      }   
	     end         
    }
    if check_proxy.length > 0
      ezproxy = EzproxyClient.new
      proxied_links = ezproxy.proxy_links(check_proxy)
      unless proxied_links.empty?
        relevant_results += proxied_links
      end
    end
    @relevant_links = relevant_results
  end

  def load_relevant_sites
    sites = []
    RelevantSite.find(:all).each { | site |
      sites << site.hostname
    }
    file = File.new( "vendor/roar.xml" )    
    doc = REXML::Document.new file 
    REXML::XPath.each(doc, "/fr:friends/baseURL", {"fr"=>"http://www.openarchives.org/OAI/2.0/friends/"}) { |url|
      host = URI.parse(url.get_text.value.chomp)
      sites << host.host
    }
    return sites
  end
  
  def is_interesting?(host)
    h = RelevantSite.find_by_hostname(host)
    if h.nil?
      return false
    end
    return h.handler
  end
  def get_interesting_site(link, context_object)    
    handler = self.is_interesting?(URI.parse(link[:url]).host)
    if handler != ""
      client = eval(handler.capitalize+"Client").new
      return client.make_interesting(link, context_object)
    end
  end  
  def load_irrelevant_sites
    sites = []
    IrrelevantSite.find(:all).each { | site |
      sites << site.hostname
    }
    return sites
  end  
	
  def to_xml(document=nil) 
  	doc = REXML::Document.new document
  	unless root = doc.elements['umlaut']
  		root = doc.add_element 'umlaut'
  	end
  	service_root = root.add_element 'services'
  	unless @fulltext_links.empty?
  		ft_root = service_root.add_element 'fulltext_links'
  		@fulltext_links.each { | ft | 
  			ft_link = ft_root.add_element 'target', 'source'=>ft[:source], 'display_text'=>ft[:display_text]
				ft_url = ft_link.add_element 'url'
				ft_url.text = ft[:url]
  			unless ft[:coverage] == ""
  				coverage = ft_link.add_element 'coverage'
  				coverage.text = ft[:coverage]
  			end
  		}
  	end
  	unless @external_links.empty?
  		el_root = service_root.add_element 'external_links'
  		@external_links.each_key { | el | 
  			el_source = el_root.add_element el.to_s, 'number_of_results'=>@external_links[el].length.to_s
  			@external_links[el].each { | results |
  				result = el_source.add_element 'result'
  				res_title = result.add_element 'title'
  				res_title.text = results[:title]
  				res_url = result.add_element 'url'
  				res_url.text = results[:url]
  				res_desc = result.add_element 'description'
  				res_desc.text = results[:description]
  			}
  		}
  	end  	
  	unless @similar_items.empty?
  		sim_root = service_root.add_element 'similar_items'
  		@similar_items.each_key { | si | 
  			si_source = sim_root.add_element si.to_s.gsub(/[\s:]/, "_").gsub(/[@\&\<\>!?#\[\]\^\*\(\)\/]/, '')
  			@similar_items[si].each { | item |
  				result = si_source.add_element 'item'
  				if item[:title]
	  				res_title = result.add_element 'title'
  					res_title.text = item[:title]
  				end
  				if item[:context_object]
  					co = REXML::Document.new item[:context_object].xml
  					result.add co.root
  				end
  				if item[:uri]
  					res_url = result.add_element 'url'
  					res_url.text = item[:uri]
  				end
  				if item[:description]
  					res_description = result.add_element 'description'
  					res_description.text = item[:description]
  				end
  			}
  		}
  	end 
  	
  	unless @subjects.empty?
  		subjects = service_root.add_element 'subjects'
  		@subjects.each_key { | source |
  			@subjects[source].each { | s |
  				subject = subjects.add_element 'subject', 'source'=>source.to_s
  				subject.text = s
  			}
  		}  	
  	end
  	unless @cover_art.empty?
  		art = service_root.add_element 'cover_art'
  		@cover_art.each_key { | size |
  			sz = art.add_element size.to_s, 'url'=>@cover_art[size]
  		}
  	end	 
  	
  	unless @description.empty?
  		@description.each { |desc|
  			descrip = service_root.add_element 'description'
  			descrip.text = desc[:content]
  			if desc[:source]
  				descrip.attributes['source'] = desc[:source]
  			end
  			if desc[:url]
  				descrip.attributes['url'] = desc[:url]
  			end  			
  		}
  	end 	
  	
  	unless @highlighted_links.empty?
  		hls = service_root.add_element 'highlighted_links'
  		@highlighted_links.each { | highlight |
  			hl = hls.add_element 'link', 'type'=>highlight[:type]
  			hl_title = hl.add_element 'title'
  			hl_title.text = highlight[:title]
  			hl_url = hl.add_element 'url'
  			hl_url.text = highlight[:url]
  		}
  	end
  	unless @print_locations.empty?
  		pls = service_root.add_element 'print_locations'
  		@print_locations.each { | pl |
  			location = pls.add_element 'print_location', 'source'=>pl[:source_name], 'url'=>pl[:url]
				call_no = location.add_element 'call_number'
				call_no.text = pl[:call_number]
				loc = location.add_element 'location', 'location_code'=>pl[:location]
				loc.text = pl[:display_text]
				status = location.add_element 'status'
				status.text = pl[:status]
  		}
  	end
  	
  	unless @table_of_contents.empty?
  		@table_of_contents.each { | contents |
	  		toc = service_root.add_element 'table_of_contents'
	  		toc.text = contents
  		}
  	end
  	unless @related_titles.empty?
  		rt = service_root.add_element 'related_title'
  		@related_titles.each { | title |
  			rel_title = rt.add_element 'item', 'relation'=>title[:relation]
  			rel_title_title = rel_title.add_element 'title'
  			rel_title_title.text = title[:title]
  			if title[:context_object]
  				rel_co = REXML::Document.new title[:context_object].xml
  				rel_title.add rel_co.root
  			end
  		}
  	end
	
    unless @document_delivery.empty?
    	@document_delivery.each { | doc_del |
    		docdel = service_root.add_element 'document_delivery', 'source'=>doc_del[:source]
    		docdel_label = docdel.add_element 'display_text'
    		docdel_label.text = doc_del[:display_text]
    		docdel_url = docdel.add_element 'url'
    		docdel_url.text = doc_del[:url]
    	}
    end
    return doc
  end
end
