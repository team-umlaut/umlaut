class DispatchedService < ActiveRecord::Base
  belongs_to :request
  def service=(service)
    self.service_name = service.id
  end
end
