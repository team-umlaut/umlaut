class RequestAddHttpParams < ActiveRecord::Migration
  def self.up
    add_column :requests, :http_env, :string, :limit => 2048
  end

  def self.down
    remove_column :requests, :http_env
  end
end
