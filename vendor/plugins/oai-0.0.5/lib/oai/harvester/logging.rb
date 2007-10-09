# Reopen Harvest and add logging
module OAI
  module Harvester

    class Harvest
      alias_method :orig_start, :start
      alias_method :orig_harvest, :harvest
      alias_method :orig_call, :call
      alias_method :orig_init, :initialize
    
      def initialize(config = nil, directory = nil, date = nil)
        orig_init(config, directory, date)
        @summary = []
        @logger = Logger.new(File.join(@config.logfile, "harvester.log"), 
          shift_age = 'weekly') if @config.logfile
        @logger.datetime_format = "%Y-%m-%d %H:%M"
      
        # Turn off logging if no logging directory is specified.
        @logger.level = Logger::FATAL unless @config.logfile
      end
    
      def start(sites = nil, interactive = false)
        if not interactive
          @logger.info { "Starting regular harvest" }
          orig_start(sites)
          begin
            OAI::Harvester::
              Mailer.send(@config.mail_server, @config.email, @summary)
          rescue
            @logger.error { "Error sending out summary email: #{$!}"}
          end
        else
          @logger.info { "Starting interactive harvest"}
          orig_start(sites, true)
        end
      end
    
      private
    
      def harvest(site)
        begin
          @logger.info { "Harvest of '#{site}' starting" }
          @summary << "Harvest of '#{site}' attempted"
          orig_harvest(site)
        rescue OAI::Exception
          if "noRecordsMatch" == $!.code
            @logger.info "No new records available"
            @summary << "'#{site}' had no new records."
          else
            @logger.error { "Harvesting of '#{site}' failed, message: #{$!}" }
            @summary << "'#{site}' had an OAI Error! #{$!}"
          end
        rescue
          @logger.error { "Harvesting of '#{site}' failed, message: #{$!}" }
          @logger.error { "#{$!.backtrace.join('\n')}" }
          @summary << "'#{site}' had an Error! #{$!}"
        end
      end
    
      def call(url, options)
        @logger.info { "fetching: #{url} with options #{options.inspect}" }
        file, records = orig_call(url, options)
        @logger.info { "retrieved #{records} records" }
        @summary << "Retrieved #{records} records."
        return file, records
      end
    end
    
  end
end
