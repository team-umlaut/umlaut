class CreateServiceTypeValues < ActiveRecord::Migration
  def self.up
    create_table :service_type_values do |t|
      t.column :name, :string  # Internal name used with enumerations_mixin
      t.column :display_name, :string # user-displayable name
      t.column :display_name_plural, :string # pluralizing is tricky, ie "Table of Contents", "Tables of Contents". Just do it manually. 
    end
  end

  def self.down
    drop_table :service_type_values
  end
end
