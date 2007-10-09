class DCSet < ActiveRecord::Base
  has_and_belongs_to_many :dc_fields, 
    :join_table => "dc_fields_dc_sets", 
    :foreign_key => "dc_set_id",
    :class_name => "DCField"
end