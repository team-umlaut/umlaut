# The SFX A-Z "version 2" title table. 

module SfxDb
  class AzTitleV2 < SfxDbBase
    self.table_name = 'AZ_TITLE'
    self.primary_key = 'OBJECT_ID' # This is a lie, it's really a compound pk, but it works anyway for what we need. Rails doesn't do compound pks formally. 

    belongs_to :object,
               :foreign_key => 'OBJECT_ID'

    def to_context_object
      #require 'open_url'
      co = OpenURL::ContextObject.new
      co.referent.set_metadata('jtitle', self.TITLE_DISPLAY)
      co.referent.set_metadata('object_id', self.OBJECT_ID)

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
