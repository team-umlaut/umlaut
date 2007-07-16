class ResponseNewFields < ActiveRecord::Migration
  def self.up
    add_column :service_responses, :display_text, :string
    add_column :service_responses, :url, :string
    add_column :service_responses, :note, :text
    add_column :service_responses, :service_data, :text
  end

  def self.down
    remove_column :service_responses, :display_text
    remove_column :service_responses, :url
    remove_column :service_responses, :note
  end
end
