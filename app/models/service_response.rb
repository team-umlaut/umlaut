class ServiceResponse < ActiveRecord::Base
  has_many :service_types
  def service
    return ServiceList.get(ft.service_response.service_id)
  end
end
