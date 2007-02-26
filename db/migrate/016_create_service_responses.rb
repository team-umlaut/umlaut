class CreateServiceResponses < ActiveRecord::Migration
  def self.up
    create_table :service_responses do |t|
    end
  end

  def self.down
    drop_table :service_responses
  end
end
