class ServiceResponsesCreatedAt < ActiveRecord::Migration
  def self.up
    add_column :service_responses, :created_at, :datetime
    # Let's set all existing ones to a day ago, why not. 
    connection = ServiceResponse::connection()
    puts "-- Adding faked created_at dates to service_responses..."
    connection.update("UPDATE service_responses SET created_at = '#{(Time.now - 1.day).strftime("%Y-%m-%d %H:%M:%S")}' ")

    # Add it to dispatched_services too
    add_column :dispatched_services, :created_at, :datetime
    puts "-- Adding faked created_at dates to dispatched_services"
    connection.update("UPDATE dispatched_services SET created_at = '#{(Time.now - 1.day).strftime("%Y-%m-%d %H:%M:%S")}' ")

    
  end

  def self.down
    remove_column :service_responses, :created_at
    remove_column :dispatched_services, :created_at
  end
end
