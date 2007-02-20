class PrintLocation < ActiveRecord::Base
    belongs to :request
    belongs_to :service
end
