class LinkResolver < ActiveRecord::Base
  has_and_belongs_to_many :institutions
  belongs_to :vendor
end
