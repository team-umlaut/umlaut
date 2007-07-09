class FixDispatchedServicesIdColumn < ActiveRecord::Migration
  def self.up
    change_column :dispatched_services, :service_id, :string, :null => false
  end

  def self.down
    change_column :dispatched_services, :service_id, :integer
  end
end
