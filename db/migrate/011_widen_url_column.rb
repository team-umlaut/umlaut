class WidenUrlColumn < ActiveRecord::Migration
  def self.up
    change_column :service_responses, :url, :string, :limit=>1024
  end

  def self.down
    change_column :service_responses, :url, :string
  end
end
