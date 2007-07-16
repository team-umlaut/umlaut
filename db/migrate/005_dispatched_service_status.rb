class DispatchedServiceStatus < ActiveRecord::Migration
  def self.up
    # Add status column
    add_column :dispatched_services, :status, :string
    # Migrate data from old 'succesful' column
    # Use the AR connection for  direct sql.
    # See documentation for module
    # ActiveRecord::ConnectionAdapters::DatabaseStatements
    # Cause that's what I'm getting I think. 
    connection = ActiveRecord::Base::connection()
    connection.update("UPDATE dispatched_services SET status = '#{DispatchedService::Successful}' where successful = true")
    connection.update("UPDATE dispatched_services SET status = '#{DispatchedService::FailedTemporary}' where successful = false")
    
    # delete succesful column
    remove_column :dispatched_services, :successful
  end

  def self.down
    # Add succesful column back
    add_column :dispatched_services, :successful, :boolean
    # Migrate data from status column
    connection = ActiveRecord::Base::connection()
    connection.update("UPDATE dispatched_services SET successful = true WHERE status = '#{DispatchedService::Successful}'")
    connection.update("UPDATE dispatched_services  SET successful = false WHERE status = '#{DispatchedService::FailedTemporary}'")

    # delete status column
    remove_column :dispatched_services, :status
  end
end
