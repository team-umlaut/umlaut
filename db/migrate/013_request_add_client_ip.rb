class RequestAddClientIp < ActiveRecord::Migration
  def self.up
    add_column :requests, :client_ip_addr, :string
    add_column :requests, :client_ip_is_simulated, :boolean
  end

  def self.down
    remove_column :requests, :client_ip_addr
    remove_column :requests, :client_ip_is_simulated
  end
end
