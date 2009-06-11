# undo MoreDescriptionForTypes, we don't actually need it
class LessDescriptionForTypes < ActiveRecord::Migration
  def self.up
    remove_column :service_type_values, :section_heading
    remove_column :service_type_values, :section_prompt
  end

  def self.down
    add_column :service_type_values, :section_heading, :string
    add_column :service_type_values, :section_prompt, :string    
  end
end
