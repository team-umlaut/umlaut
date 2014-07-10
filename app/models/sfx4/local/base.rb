module Sfx4
  module Local
    class Base < ActiveRecord::Base
      # Was a SFX DB connection set in database.yml to connect directly to sfx?
      def self.connection_configured?
        config = ActiveRecord::Base.configurations["sfx_db"]
        (not (config.nil? or config.blank? or config["adapter"].blank?))
      end

      self.establish_connection :sfx_db if self.connection_configured?

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
