# +------------------+---------------------+------+-----+---------+----------------+
# | Field            | Type                | Null | Key | Default | Extra          |
# +------------------+---------------------+------+-----+---------+----------------+
# | AZ_EXTRA_INFO_ID | int(10) unsigned    | NO   | PRI | NULL    | auto_increment |
# | AZ_PROFILE       | varchar(100)        | NO   |     | NULL    |                |
# | OBJECT_ID        | bigint(20) unsigned | NO   | MUL | 0       |                |
# | EXTRA_INFO_XML   | mediumtext          | YES  |     | NULL    |                |
# +------------------+---------------------+------+-----+---------+----------------+
module Sfx4
  module Local
    module Abstract
      module AzExtraInfo
      
        def self.included(klass)
          klass.class_eval do
            require 'nokogiri'
            self.table_name = 'AZ_EXTRA_INFO'
            self.primary_key = 'AZ_EXTRA_INFO_ID'

            belongs_to :az_title,
                       :foreign_key => 'AZ_TITLE_ID',
                       :class_name => "#{klass.to_s.deconstantize}::AzTitle"

            include MetadataHelper # for normalize_lccn
            include InstanceMethods
          end
        end
      
        module InstanceMethods
          def issn
            @issn ||= extra_info_xml.search("item[key=issn]").text
          end
      
          def isbn
            @isbn ||= extra_info_xml.search("item[key=isbn]").text
          end
        
          def lccn
            @lccn ||= normalize_lccn(extra_info_xml.search("item[key=lccn]").text)
          end
      
          def extra_info_xml
            @extra_info_xml ||= Nokogiri::XML(EXTRA_INFO_XML)
          end
        end
      end
    end
  end
end