class Institution < ActiveRecord::Base
  has_and_belongs_to_many :services, :order=>'dispatch_priority'
  has_and_belongs_to_many :users
end
