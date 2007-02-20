class WebLink < ActiveRecord::Base
  belongs_to :request
  belongs_to :service
end
