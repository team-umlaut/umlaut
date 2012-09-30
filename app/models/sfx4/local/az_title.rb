module Sfx4
  module Local
    class AzTitle < ActiveRecord::Base
      include Sfx4::Local::Abstract::AzTitle
      include Sfx4::Local::Connection
    end
  end
end
