class ServiceResponse < ActiveRecord::Base
  has_many :service_types
  def service
    return ServiceList.get( self.service_id )
  end
end
