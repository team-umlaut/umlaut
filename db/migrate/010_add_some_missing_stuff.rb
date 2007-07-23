# Add some constraints and indexes I forgot to add before. 
class AddSomeMissingStuff < ActiveRecord::Migration
  def self.up
    add_index :service_types, :service_type_value_id
    change_column :dispatched_services, :status, :string, :null => false
    # better name for current use
    rename_column :dispatched_services, :exception, :exception_info
  end

  def self.down
    remove_index :service_types, :service_type_value_id
    change_column :dispatched_services, :status, :string, :null => true
    rename_column :dispatched_services, :exception_info, :exception
  end
end
