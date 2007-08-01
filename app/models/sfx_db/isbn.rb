module SfxDb
  class Isbn < SfxDbBase
    self.table_name = "ISBN"
    self.primary_key = "ISBN_INTERNAL_ID"

    belongs_to :object,
               :foreign_key => 'OBJECT_ID'
  end
end
