class ServiceType < ActiveRecord::Base
  belongs_to :request
  belongs_to :service_reponses
end
