# remove old service_type column from ServiceType model. Now we use
# service_type_value, with an fk to ServiceTypeValue instead. 
class RemoveServiceType < ActiveRecord::Migration
  def self.up
    remove_column :service_types, :service_type
  end

  def self.down
    add_column :service_types, :service_type, :string, :limit => 35, :default => "", :null => false
  end
end
