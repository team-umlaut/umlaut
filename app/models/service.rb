class Service < ActiveRecord::Base
  has_and_belongs_to_many :institutions
  has_many :background_services
  has_one :catalog
end
