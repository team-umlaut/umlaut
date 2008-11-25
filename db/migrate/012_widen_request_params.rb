class WidenRequestParams < ActiveRecord::Migration
  def self.up
    change_column :requests, :params, :string, :limit => 2048
  end

  def self.down
    change_column :requests, :params, :string, :limit => 1024
  end
end
