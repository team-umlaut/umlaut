class AddQueryColumn < ActiveRecord::Migration
  def self.up
    add_column :requests, :params, :string, :limit => 1024
  end

  def self.down
    remove_column :requests, :params
  end
end
