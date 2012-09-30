# +----------------------+------------------+------+-----+---------+----------------+
# | Field                | Type             | Null | Key | Default | Extra          |
# +----------------------+------------------+------+-----+---------+----------------+
# | AZ_LETTER_GROUP_ID   | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
# | AZ_TITLE_ID          | int(10) unsigned | NO   |     | 0       |                |
# | AZ_LETTER_GROUP_NAME | char(10)         | NO   | MUL |         |                |
# +----------------------+------------------+------+-----+---------+----------------+
module Sfx4
  module Local
    module Abstract
      module AzLetterGroup
        def self.included(klass)
          klass.class_eval do
            self.table_name = 'AZ_LETTER_GROUP'
            self.primary_key = 'AZ_LETTER_GROUP_ID'

            belongs_to :az_title,
                       :foreign_key => 'AZ_TITLE_ID',
                       :class_name => "#{klass.to_s.deconstantize}::AzTitle"

          end
        end
      end
    end
  end
end