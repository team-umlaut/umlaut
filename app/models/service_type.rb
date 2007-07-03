class ServiceType < ActiveRecord::Base
  belongs_to :request
  belongs_to :service_response

  # convenience method to skip accross relationships to this method, since
  # if often must be done.
  def view_data_from_service_type
    service_response.service.view_data_from_service_type( self )
  end
end
