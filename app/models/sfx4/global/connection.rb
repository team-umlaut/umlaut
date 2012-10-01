module Sfx4
  module Global
    module Connection
      def self.included(klass)
        klass.class_eval do
          self.establish_connection :sfx4_global unless self.configurations[:sfx4_global].nil?
        end
      end
    end
  end
end
