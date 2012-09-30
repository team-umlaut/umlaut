module Sfx4
  module Local
    class AzTitleSearch < ActiveRecord::Base
      include Sfx4::Local::Abstract::AzTitleSearch
      include Sfx4::Local::Connection
    end
  end
end
