module SfxDb
  class AzLetterGroup < SfxDbBase
    self.table_name = 'AZ_LETTER_GROUP_VER3'
    self.primary_key = 'AZ_LETTER_GROUP_VER3_ID'

    belongs_to :az_title,
               :foreign_key => 'AZ_TITLE_VER3_ID',
               :class_name => "SfxDb::AzTitle"

  end
end
