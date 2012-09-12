module SfxDb
  class AzTitle < SfxDbBase
    self.table_name = 'AZ_TITLE_VER3'
    self.primary_key = 'AZ_TITLE_VER3_ID'

    belongs_to  :object,
                :foreign_key => 'OBJECT_ID',
                :class_name => "SfxDb::Object"
               
    has_many  :az_additional_titles,
              :foreign_key => 'AZ_TITLE_VER3_ID',
              :class_name => "SfxDb::AzAdditionalTitle"

    has_many  :az_letter_groups,
              :foreign_key => 'AZ_TITLE_VER3_ID',
              :class_name => "SfxDb::AzLetterGroup"

    def to_context_object
      #require 'openurl'
      co = OpenURL::ContextObject.new
      # Make sure it uses a journal type referent please, that's what we've
      # got here.
      co.referent = OpenURL::ContextObjectEntity.new_from_format( 'info:ofi/fmt:xml:xsd:journal' )
      
      
      co.referent.set_metadata('jtitle', self.TITLE_DISPLAY)
      co.referent.set_metadata('object_id', self.OBJECT_ID.to_s)

      # Add publisher stuff, if possible.
      pub = self.object ? self.object.publishers.first : nil
      if ( pub )
        co.referent.set_metadata('pub', pub.PUBLISHER_DISPLAY )
        co.referent.set_metadata('place', pub.PLACE_OF_PUBLICATION_DISPLAY)
      end      
      
      return co
    end
    
  end
end
