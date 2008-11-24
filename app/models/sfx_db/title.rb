module SfxDb
  class Title < SfxDbBase    
    self.table_name = 'TITLE'
    self.primary_key = 'TITLE_INTERNAL_ID'

    belongs_to  :object,
                :foreign_key => 'OBJECT_ID',
                :class_name => "SfxDb::Object"
  end
end
