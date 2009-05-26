class MoreDescriptionForTypes < ActiveRecord::Migration
  def self.up
    add_column :service_type_values, :section_heading, :string
    add_column :service_type_values, :section_prompt, :string
  end

  def self.down
    remove_column :service_type_values, :section_heading
    remove_column :service_type_values, :section_prompt
  end
end
