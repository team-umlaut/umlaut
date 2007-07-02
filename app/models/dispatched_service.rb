class DispatchedService < ActiveRecord::Base
  belongs_to :request
  def service=(service)
    self.service_id = service.id
  end  
end
