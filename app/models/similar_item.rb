class SimilarItem < ActiveRecord::Base
  belongs_to :request
  belongs_to :service
  belongs_to :referent
end
