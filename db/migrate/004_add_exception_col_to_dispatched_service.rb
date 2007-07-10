class AddExceptionColToDispatchedService < ActiveRecord::Migration
  def self.up
    add_column :dispatched_services, :exception, :text
  end

  def self.down
    remove_column :dispatched_services, :exception
  end
end
