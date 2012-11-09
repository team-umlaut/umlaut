# +--------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------+------+-----+------------------------+-----------------------------+
# | Field                    | Type                                                                                                                                                      | Null | Key | Default                | Extra                       |
# +--------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------+------+-----+------------------------+-----------------------------+
# | OBJECT_ID                | bigint(20) unsigned                                                                                                                                       | NO   | PRI | NULL                   | auto_increment              |
# | OBJECT_TYPE              | enum('JOURNAL','BOOK','DISSERTATION','PROCEEDING','CONFERENCE','REPORT','DOCUMENT','SERIES','NEWSPAPER','TRANSCRIPT','DATABASE','WIRE','CD','MANUSCRIPT') | YES  | MUL | NULL                   |                             |
# | LANGUAGE                 | char(3)                                                                                                                                                   | NO   | MUL | eng                    |                             |
# | PEER_REVIEWED            | enum('YES','NO')                                                                                                                                          | YES  |     | NO                     |                             |
# | OWNER                    | varchar(100)                                                                                                                                              | NO   |     |                        |                             |
# | AVAILABLE_FOR            | varchar(100)                                                                                                                                              | NO   |     |                        |                             |
# | ATTR_XML                 | mediumtext                                                                                                                                                | YES  |     | NULL                   |                             |
# | MMS_ID                   | bigint(20) unsigned                                                                                                                                       | NO   |     | NULL                   |                             |
# | STATUS                   | enum('ACTIVE','WITHDRAWN')                                                                                                                                | YES  |     | ACTIVE                 |                             |
# | STATUS_DATE              | timestamp                                                                                                                                                 | NO   |     | 0000-00-00 00:00:00    |                             |
# | DISTRIBUTION_STATUS      | enum('READY FOR DISTRIBUTION','NOT FOR DISTRIBUTION')                                                                                                     | YES  |     | READY FOR DISTRIBUTION |                             |
# | DISTRIBUTION_STATUS_DATE | timestamp                                                                                                                                                 | NO   |     | 0000-00-00 00:00:00    |                             |
# | VERSION_NUMBER           | int(10)                                                                                                                                                   | NO   |     | 1                      |                             |
# | RELEASE_NUMBER           | int(10)                                                                                                                                                   | NO   |     | 1                      |                             |
# | CRUD_TYPE                | enum('CREATE','UPDATE','DELETE')                                                                                                                          | NO   |     | CREATE                 |                             |
# | CREATION_DATE            | timestamp                                                                                                                                                 | NO   |     | 0000-00-00 00:00:00    |                             |
# | CREATED_BY               | varchar(255)                                                                                                                                              | NO   |     |                        |                             |
# | LAST_UPDATE_DATE         | timestamp                                                                                                                                                 | NO   |     | CURRENT_TIMESTAMP      | on update CURRENT_TIMESTAMP |
# | LAST_UPDATED_BY          | varchar(255)                                                                                                                                              | NO   |     |                        |                             |
# +--------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------+------+-----+------------------------+-----------------------------+
module Sfx4
  module Global
    class KbObject < Sfx4::Global::Base
      self.table_name = 'KB_OBJECTS'
      self.primary_key = 'OBJECT_ID'

      has_many  :az_titles,
                :foreign_key=>'OBJECT_ID'
    end
  end
end
