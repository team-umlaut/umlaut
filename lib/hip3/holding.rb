#!/usr/bin/ruby



module Hip3
	# abstract superclass for copies and items (both serial and mono). Both a Copy
  # and an Item are Holdings. 
	# coverage_str only applies to copies and serial items, not mono items, but
	# we put it here anyway, it'll just be nil for mono items. 
	class Holding 
		attr_accessor :id, :location_str, :collection_str, :call_no, :copy_str, :status_str, :coverage_str, :notes
    # Holdings sometimes use the bib to lazy load more stuff.	
    attr_accessor :bib  
		
		# If input is nil, returns nil, else returns input.text
		def textValue(el)
			return ( el == nil ? nil : el.text)
		end
		
		# Return an array of holding strings, possibly empty, possibly single-valued.
		# over-ridden by SerialCopy to give you an array, since SerialCopies have
		# multiple holdings strings. 
		def coverage_str_to_a
			return coverage_str.nil? ? [] : [coverage_str]
		end

		# Some items are dummy/placeholder items which don't really represent
		# an item, and shouldn't be shown. Having trouble figuring out what
		# our 'business rules' for that are, so this is a messy guess. 
		def dummy?
			#Mostly trying to rule out the weird internet holdings
			#that tell us nothing--url is already in the bib. 
			return ((  (call_no == "World Wide Web" || call_no.blank?) &&
					( collection_str == "Internet" || collection_str == "Welch Online Journals" || collection_str == "Welch Online Journal")) ||
					(collection_str == "Gibson-Electronic Journals & Indexes" && call_no="Online journal")) 
				
		end
	end

		
	
	
end
