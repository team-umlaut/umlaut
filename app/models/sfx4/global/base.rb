module Sfx4
  module Global
    class Base < ActiveRecord::Base
      # Was a SFX Global DB connection set in database.yml to connect directly to sfx?
      def self.connection_configured?
        config = ActiveRecord::Base.configurations["sfx4_global"]
        (not (config.nil? or config.blank? or config[:adapter].blank?))
      end

      self.establish_connection :sfx4_global if self.connection_configured?
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
