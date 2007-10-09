class AddServiceTypeIndexes < ActiveRecord::Migration
  def self.up
    # Composite query on request_id and service_response_id does NOT cut it!
    # We need individual index on service_response_id too.    
    add_index :service_types, :service_response_id
  end

  def self.down
    remove_index :service_types, :service_response_id
  end
end
