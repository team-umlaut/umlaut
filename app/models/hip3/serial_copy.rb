module Hip3
  # Keeps a reference to it's bib, if it needs to load it's data, 
  # it asks bib to load all
	# data, and the bib loads it at once for all copies, in one fetch. 	
	class SerialCopy < Holding
		@@Field_labels = {:location => 'Location', :collection => 'Collection', :call_no => 'Call No.', :copy_str => 'Copy No.', :status => 'Status', :notes => 'Notes'}
		attr_accessor :items # array of items
		attr_accessor :items_loaded
		attr_accessor :runs # array of run types/statements
		
		def initialize(argBibObj, serialXmlElement=nil)
			self.bib = argBibObj
			self.items_loaded = false
			if ( serialXmlElement ) 
				loadFromSerialElement( serialXmlElement )
			end
		end
		
		def items 
			bib.load_items_from_store if ! items_loaded?
			
			return @items || []
		end
		
		def items_loaded?
			return (items_loaded == true)
		end
				
		def loadFromSerialElement( serialElement )
			self.location_str = serialElement.at('/location').inner_text
			self.id = serialElement.at('/copykey').inner_text
			
			# Okay, this part is potentially fragile, we have to pull out based on
			# order in the XML, not sure if that can change. Sorry, that's HIP for you.
			copyElements = serialElement.search('/copy/cell/data/text').collect {|e| e.inner_text}
			# Fix this to use field lookup
			self.location_str = bib.copy_field_lookup.text_value_for(copyElements, @@Field_labels[:location])
			self.collection_str =  bib.copy_field_lookup.text_value_for(copyElements, @@Field_labels[:collection])
			self.call_no = bib.copy_field_lookup.text_value_for(copyElements, @@Field_labels[:call_no])
			self.copy_str = bib.copy_field_lookup.text_value_for(copyElements, @@Field_labels[:copy_str])
			self.status_str = bib.copy_field_lookup.text_value_for(copyElements, @@Field_labels[:status])
			self.notes = bib.copy_field_lookup.text_value_for(copyElements, @@Field_labels[:notes])
			
			
			#Okay, got to get the 'runs' for summary holdings info.
			self.runs ||= []
			serialElement.search('/runlist/run').each do |run|
				label = run.at('/runlabel').inner_text
				run.search('/data/rundata').each do |rundata|
          run = {:label => label, :statement => textValue(rundata.at('/text'))}
          run[:note] = textValue(rundata.at('/note'))
				  
          self.runs.push( run )
				end
			end
		end	
		
		# Not too useful, use coverage_str_to_a instead usually
		def coverage_str
			return runs.to_s
		end
		
		# Over-riding
		def coverage_str_to_a
			runs.collect do |r|
        s = ''
        (s << r[:label] << ": ") if (! r[:label].blank?) && r[:label] != "Main run"
        s << r[:statement]
        s << '-- ' << r[:note] if r[:note]
        s
      end
		end
		
		def register_item(item)
			items ||= []
			
			unless items.include?(item)
				items.push(item)
			end
		end
	end
end
