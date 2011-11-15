class ServiceTypeValueRefactor < ActiveRecord::Migration
  def self.up
    drop_table :service_type_values
    remove_column :service_types, :service_type_value_id
    add_column :service_types, :service_type_value_name, :string
  end

  def self.down
    create_table "service_type_values" do |t|
      t.string   "name"
      t.string   "display_name"
      t.string   "display_name_plural"
      t.datetime "updated_at"
    end
    
    add_column :service_types, :service_type_value_id, :integer
    drop_column :service_type_value_name

  end
end
