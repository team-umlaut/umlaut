module Sfx4
  module Local
    class Base < ActiveRecord::Base
      self.establish_connection :sfx_db
      # ActiveRecord likes it when we tell it this is an abstract
      # class only. 
      self.abstract_class = true 
      extend Sfx4::Abstract::Base

      # All SFX things are read-only!
      def readonly?() 
        return true
      end
    end
  end
end
