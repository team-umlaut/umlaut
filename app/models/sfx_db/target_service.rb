module SfxDb
  class TargetService < SfxDbBase
    self.table_name = 'TARGET_SERVICE'
    self.primary_key = 'INTERNAL_ID'

    belongs_to :target,
               :foreign_key => 'TARGET'
  end
end
