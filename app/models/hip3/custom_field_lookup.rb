module Hip3

# Certain fields we add to the Item/Copy/Bib display are in the XML, but they
	# are only findable by name of the field header as configured in HIP
	# admin, and then only by seeing what index in a list that header is,
	# and then finding the corresponding indexed value! This object
	# does that work for us, and caches it's calcuations while it's at it. 
	# One of these objects has it's own rexml doc representing a particular
	# bib with item info, because the answer may be different for different bibs!
	class CustomFieldLookup
		attr_accessor :header_list
		
		def initialize(a_header_list)
			self.header_list = a_header_list
			
		end
		
		
		def index_for(label)
			return header_list.index(label)
		end
		
		# list can be either an array of strings, or a rexml element 
		# representing a <row> element for this item. In either case,
		# we lookup the index i of label in our original header list,
		# and then return the text value of element i in the list arg.  
		def text_value_for(list, label )			
			i = index_for(label)
			return nil if i.nil?
				
			if ( list.kind_of?(Hpricot::Node) )
				# Assume they passed in a HIP 'row' element, turn it
				# into a nice array of strings. Can't figure out how
				# to test if it really is a 'row' element!
 				list = list.search('/cell/data/text').collect {|e| e.inner_text}
			end
			
			return list.at( i )
				
		end


	end				
end
