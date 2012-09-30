module Sfx4
  module Local
    class AzExtraInfo < ActiveRecord::Base
      include Sfx4::Local::Abstract::AzExtraInfo
      include Sfx4::Local::Connection
    end
  end
end
