class RemoveServiceTypeJoin < ActiveRecord::Migration
  def self.up
    add_column :service_responses, :service_type_value_name, :string
    add_column :service_responses, :request_id, :integer
    
    drop_table :service_types
  end

  def self.down
    create_table :service_types do |t|
      t.integer "request_id",              :default => 0, :null => false
      t.integer "service_response_id",     :default => 0, :null => false
      t.string  "service_type_value_name"
    end
    
    remove_column :service_responses, :request_id
    remove_column :service_responses, :service_type_value_name
    
  end
end
