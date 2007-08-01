module SfxDb
  class Issn < SfxDbBase    
    self.table_name = "ISSN"
    self.primary_key = "ISSN_INTERNAL_ID"

    belongs_to :object,
                :foreign_key => 'OBJECT_ID'
   
  end
end
