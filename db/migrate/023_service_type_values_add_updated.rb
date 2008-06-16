# Track update time to allow auto-sync of service type values on startup. 

class ServiceTypeValuesAddUpdated < ActiveRecord::Migration
  def self.up
    add_column :service_type_values, :updated_at, :datetime
  end

  def self.down
    remove_column :service_type_values, :updated_at
  end
end
