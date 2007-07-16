class ResponseNewFields < ActiveRecord::Migration
  def self.up
    add_column :service_responses, :display_text, :string
    add_column :service_responses, :url, :string
    add_column :service_responses, :notes, :text
    add_column :service_responses, :service_data, :text

    # response_key can be null now, cause we're soon getting rid of it.
    change_column :service_responses, :response_key, :string, :null => true
  end

  def self.down
    remove_column :service_responses, :display_text
    remove_column :service_responses, :url
    remove_column :service_responses, :notes
    remove_column :service_responses, :service_data

    change_column :service_responses, :response_key, :string, :default => "", :null => false
  end
end
