module SfxDb
  class AzTitle < SfxDbBase
    self.table_name = 'AZ_TITLE_VER3'
    self.primary_key = 'AZ_TITLE_VER3_ID'

    belongs_to :object,
               :foreign_key => 'OBJECT_ID'
    has_many  :az_additional_titles,
               :foreign_key => 'AZ_TITLE_VER3_ID'
    
  end
end
