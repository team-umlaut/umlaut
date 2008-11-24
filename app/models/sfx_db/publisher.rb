module SfxDb
  class Publisher < SfxDbBase
    self.table_name = "PUBLISHER"
    self.primary_key = "PUBLISHER_INTERNAL_ID"

    belongs_to :object,
               :foreign_key => 'OBJECT_ID',
               :class_name => "SfxDb::Object"
  end
end
