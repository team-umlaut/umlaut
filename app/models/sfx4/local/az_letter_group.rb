module Sfx4
  module Local
    class AzLetterGroup < ActiveRecord::Base
      include Sfx4::Local::Abstract::AzLetterGroup
      include Sfx4::Local::Connection
    end
  end
end
