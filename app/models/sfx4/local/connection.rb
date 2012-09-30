module Sfx4
  module Local
    module Connection
      def self.included(klass)
        klass.class_eval do
          self.establish_connection :sfx4_local
        end
      end
    end
  end
end
