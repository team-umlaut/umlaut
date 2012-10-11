# +--------------------+------------------+------+-----+---------+----------------+
# | Field              | Type             | Null | Key | Default | Extra          |
# +--------------------+------------------+------+-----+---------+----------------+
# | AZ_TITLE_SEARCH_ID | int(10) unsigned | NO   | PRI | NULL    | auto_increment |
# | AZ_PROFILE         | varchar(100)     | NO   | MUL | NULL    |                |
# | AZ_TITLE_ID        | int(10) unsigned | NO   | MUL | 0       |                |
# | TITLE_SEARCH       | text             | NO   | MUL | NULL    |                |
# +--------------------+------------------+------+-----+---------+----------------+
module Sfx4
  module Abstract
    module AzTitleSearch
      def self.included(klass)
        klass.class_eval do
          self.table_name = 'AZ_TITLE_SEARCH'
          self.primary_key = 'AZ_TITLE_SEARCH_ID'

          belongs_to :az_title,
                     :foreign_key => 'AZ_TITLE_ID',
                     :class_name => "#{klass.to_s.deconstantize}::AzTitle"
        end
      end
    end
  end
end