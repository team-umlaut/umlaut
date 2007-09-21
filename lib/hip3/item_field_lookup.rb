module Hip3

# DELETE ME. Replaced by CustomFieldLookup. 
	
# Certain fields we add to the Item/Copy/Bib display are in the XML, but they
	# are only findable by name of the field header as configured in HIP
	# admin, and then only by seeing what index in a list that header is,
	# and then finding the corresponding indexed value! This object
	# does that work for us, and caches it's calcuations while it's at it. 
	# One of these objects has it's own rexml doc representing a particular
	# bib with item info, because the answer may be different for different bibs!
	class ItemFieldLookup 
		attr_accessor :rexml, :header_elements, :cached_indexes
		attr_accessor :path_to_header_elements
		
		def initialize(a_rexml, a_path_to_header = nil)
			self.rexml = a_rexml
			self.cached_indexes = {}
			
			@path_to_header_elements = a_path_to_header			
			@path_to_header_elements ||= 'searchresponse/items/searchresults/header/col' # default to value for item fields
		end
		
		def rexml=(arg)
			@rexml = arg
			#uncache
			self.cached_indexes = {}
		end
		
		def header_elements
			
			header_elements = rexml.elements.to_a(@path_to_header_elements) unless (header_elements)
			
			return header_elements
		end
		
		
		def index_for(label)
			found_index = cached_indexes[label]
			unless (found_index)
				header_elements.each_with_index do | colEl, index |
					if ( colEl.elements['label'].text == label)
						found_index = cached_indexes[label] = index
						break
					end
				end
			end
			return found_index
		end
		
		# row_xml is an rexml representing a <row> element for this item.
		def text_value_for(row_xml, label )			
			index = x_index_for(label)
			
			if ( index.nil?)
				return nil
			end
			
			
			el = row_xml.elements["cell[#{index}]/data/text"]
			if ( el.nil?)
				return nil
			end
			return el.text
		end


		# XPath indexes start at 1, not 0. 
		def x_index_for(label)
			return index_for(label).nil? ? nil : (index_for(label)+1)
		end
	end				
end
