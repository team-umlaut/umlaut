class CreateDispatchedServices < ActiveRecord::Migration
  def self.up
    create_table :dispatched_services do |t|
    end
  end

  def self.down
    drop_table :dispatched_services
  end
end
