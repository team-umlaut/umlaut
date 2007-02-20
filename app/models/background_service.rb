class BackgroundService < ActiveRecord::Base
  belongs_to :request
  belongs_to :service
end
