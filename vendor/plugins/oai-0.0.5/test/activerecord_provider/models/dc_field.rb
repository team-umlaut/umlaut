class DCField < ActiveRecord::Base
  set_inheritance_column 'DONOTINHERIT'
  has_and_belongs_to_many :sets, 
    :join_table => "dc_fields_dc_sets", 
    :foreign_key => "dc_field_id", 
    :class_name => "DCSet"
end
