module Sfx4
  module Global
    class Base < ActiveRecord::Base
      self.establish_connection :sfx4_global

      # ActiveRecord likes it when we tell it this is an abstract
      # class only. 
      self.abstract_class = true 

      # All SFX things are read-only!
      def readonly?() 
        return true
      end
    end
  end
end
