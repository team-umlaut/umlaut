module SfxDb
  class Object < SfxDbBase
    self.table_name = "OBJECT"
    self.primary_key = "OBJECT_ID"

    #has_many :issns,
    #          :foreign_key => 'OBJECT_ID'
    has_many  :titles,
              :foreign_key => 'OBJECT_ID'
    has_many   :publishers,
              :foreign_key => 'OBJECT_ID'
    has_many  :az_titles,
              :foreign_key=>'OBJECT_ID'

    has_many :primary_isbns,
             :class_name => 'Isbn',
             :foreign_key => 'OBJECT_ID',
             :conditions => "ISBN_HIERARCHY = 'PRIMARY'"

    has_many :primary_issns,
             :class_name => 'Issn',
             :foreign_key => 'OBJECT_ID',
             :conditions => "ISSN_HIERARCHY = 'PRIMARY'"

    has_many :main_titles,
             :class_name => 'Title',
             :foreign_key => 'OBJECT_ID',
             :conditions => "TITLE_TYPE = 'main'"
  end
end
