module SfxDb
  class Target < SfxDbBase
      self.table_name = 'TARGET'
      self.primary_key = 'INTERNAL_ID'

      has_many  :target_services,
                :foreign_key => 'TARGET',
                :class_name => "SfxDb::TargetService"
  end
end
