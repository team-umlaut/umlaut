class RemoveRequestParams < ActiveRecord::Migration
  def self.up
    remove_index :requests, :name => :index_requests_on_params
    remove_column :requests, :params
  end

  def self.down
    add_column :requests, :params, :string, :limit => 2048
    add_index "requests", ["params"], :name => "index_requests_on_params"  
  end
end
