class Subject < ActiveRecord::Base
  belongs_to :request
  belongs_to :service
  validates_uniqueness_of :term, :on => :create, :scope=>[:referent_id, :authority, :source]
end
