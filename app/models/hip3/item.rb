module Hip3
  # We're going to try using this for serial items and mono items. Only difference is
	# that serial items have a relationship to a SerialCopy, stored in :copy attribute.
  # Item objects need to be initialized with reXML object representing
  # the item element. 
	class Item < Holding
		# Labels set up in HIP admin item display to expose these data of interest. 
		@@Field_labels = { :rmst => 'hide_rmst', :barcode => 'hide_barcode', :copy_id => 'hide_CopyNum'}
		
		# Item-specific attributes
		attr_accessor  :avail_date_str, :rmst_str, :barcode, :copy_id
		attr_accessor :copy
	
		# Item is not lazily loadable--you need to give it
		# all three arguments to create it, you need to have the
		# XML in hand. We could certainly provide a different
		# way than XML to init values, but we haven't.
		def initialize(item_row_element, arg_bib)
			@bib = arg_bib
			loadFromItemRowElement(item_row_element)
		end
	
		def loadFromItemRowElement( el )
      
			@id = textValue(el.at('/key'));			
			
			# Pull out the values built into HIP automatically. They have weird
			# XML elements, but I think I've appropriately identified them, 
			# even though it doesn't look like it.Actually, no, those aren't
      # reliable, I don't understand what they are. We'll just pull
      # everything from the HIP display.
      
			#@copy_str = textValue(el.elements['MIDSPINE/data/text'])
      @copy_str = @bib.item_field_lookup.text_value_for(el, "Copy")
      @collection_str = @bib.item_field_lookup.text_value_for(el, "Collection")

      #Maybe. Not sure where else to get this. 
			@location_str = textValue(el.at('/LOCALLOCATION/data/text'))
      
			#@call_no = textValue(el.elements['COPYNUMBER/data/text'])
      @call_no = @bib.item_field_lookup.text_value_for(el, "Call No.")
      			
      @status_str = @bib.item_field_lookup.text_value_for(el, "Status")

      # Not sure about this one. 
			@avail_date_str = textValue(el.at('/AVAILABILITYDATE/data/text'))
			
			# Pull out the values we had to configure in Copy display
			@rmst_str = @bib.item_field_lookup.text_value_for(el, @@Field_labels[:rmst])
			@barcode = @bib.item_field_lookup.text_value_for(el, @@Field_labels[:barcode])
			@copy_id = @bib.item_field_lookup.text_value_for(el, @@Field_labels[:copy_id])
			
			# Attach this thing to the proper Copy object, in both directions. 
			# We have the Bib do it for us, since the Bib has a list of Copies.
			# Since we've set our @copy_id, the Bib can find out what it needs to.
			@bib.register_item( self)			
		end
		
		def hasSerialCopy
			return ! self.copy.nil?
		end

		
	end
end
