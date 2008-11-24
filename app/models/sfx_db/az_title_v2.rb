# The SFX A-Z "version 2" title table. 

module SfxDb
  class AzTitleV2 < SfxDbBase
    self.table_name = 'AZ_TITLE'
    self.primary_key = 'OBJECT_ID' # This is a lie, it's really a compound pk, but it works anyway for what we need. Rails doesn't do compound pks formally. 

    belongs_to :object,
               :foreign_key => 'OBJECT_ID',
               :class_name => "SfxDb::Object"

               

    def to_context_object
      co = OpenURL::ContextObject.new
      # Make sure it uses a journal type referent please, that's what we've
      # got here.
      co.referent = OpenURL::ContextObjectEntity.new_from_format( 'info:ofi/fmt:xml:xsd:journal' )
      
      co.referent.set_metadata('jtitle', self.TITLE_DISPLAY)
      co.referent.set_metadata('object_id', self.OBJECT_ID.to_s)

      # Add publisher stuff, if possible.
      pub = self.object.publishers.first
      if ( pub )
        co.referent.set_metadata('pub', pub.PUBLISHER_DISPLAY )
        co.referent.set_metadata('place', pub.PLACE_OF_PUBLICATION_DISPLAY)
      end      
      
      return co
    end
    
  end
end
