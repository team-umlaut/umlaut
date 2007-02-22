class ServiceResponse < ActiveRecord::Base
  has_many :service_types
  belongs_to :service
end
