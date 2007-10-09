#
#  Created by William Groppe on 2006-11-05.
#  Copyright (c) 2006. All rights reserved.

module OAI
  module Harvester

    LOW_RESOLUTION = "YYYY-MM-DD"
  
    class Config < OpenStruct
    
      PERIODS = %w(daily weekly monthly)
      GLOBAL = "/etc/oai/harvester.yml"
    
      def self.load
        config = find_config
        File.exists?(config) ? new(YAML.load_file(config)) : new
      end

      def save
        config = Config.find_config
        open(config, 'w') do |out|
          YAML.dump(@table, out)
        end
      end

      private 
      # Shamelessly lifted from Camping
      def self.find_config
        if home = ENV['HOME'] # POSIX
          return GLOBAL if File.exists?(GLOBAL) && File.writable?(GLOBAL)
          FileUtils.mkdir_p File.join(home, '.oai')
          File.join(home, '.oai/harvester.yml')
        elsif home = ENV['APPDATA'] # MSWIN
          File.join(home, 'oai/harvester.yml')
        end
      end
    
    end
  end
end