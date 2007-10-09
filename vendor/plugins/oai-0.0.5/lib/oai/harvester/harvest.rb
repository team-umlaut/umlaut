#
#  Created by William Groppe on 2006-11-03.

module OAI
  module Harvester
  
    class Harvest
    
      def initialize(config = nil, directory = nil, date = nil)
        @config = config || Config.load
        @directory = directory || @config.storage
        @from = date
        @from.freeze
        @parser = defined?(XML::Document) ? 'libxml' : 'rexml'
      end
    
      def start(sites = nil, interactive = false)
        @interactive = interactive
        sites = (@config.sites.keys rescue {}) unless sites
        begin
          sites.each do |site|
            harvest(site)
          end
        ensure
          @config.save
        end
      end
    
      private
    
      def harvest(site)
        harvest_time = Time.now.utc
        opts = build_options_hash(@config.sites[site])
        opts[:until] = harvest_time.xmlschema
      
        # Allow a from date to be passed in
        if(@from)
          opts[:from] = @from
        else 
          opts[:from] = earliest(opts[:url])
        end
      
        opts.delete(:set) if 'all' == opts[:set]

        begin
          # Connect, and download
          file, records = call(opts.delete(:url), opts)
      
          # Move document to storage directory
          dir = File.join(@directory, date_based_directory(harvest_time))
          FileUtils.mkdir_p dir
          FileUtils.mv(file.path, 
            File.join(dir, "#{site}-#{filename(Time.parse(opts[:from]), 
            harvest_time)}.xml.gz"))
          @config.sites[site]['last'] = harvest_time
        rescue
          raise $! unless $!.respond_to?(:code)
          raise $! if not @interactive || "noRecordsMatch" != $!.code
          puts "No new records available"
        end
      end
    
      def call(url, opts)
        # Preserve original options
        options = opts.dup
        
        records = 0;
        client = OAI::Client.new(url, :parser => @parser)
        provider_config = client.identify
        
        if Harvester::LOW_RESOLUTION == provider_config.granularity
          options[:from] = Time.parse(options[:from]).strftime("%Y-%m-%d")
          options[:until] = Time.parse(options[:until]).strftime("%Y-%m-%d")
        end
        
        file = Tempfile.new('oai_data')
        gz = Zlib::GzipWriter.new(file)
        gz << "<? xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
        gz << "<records>"
        begin
          response = client.list_records(options)
          get_records(response.doc).each do |rec|
            gz << rec
            records += 1
          end
          puts "#{records} records retrieved" if @interactive

          # Get a full response by iterating with the resumption tokens.  
          # Not very Ruby like.  Should fix OAI::Client to handle resumption
          # tokens internally.
          while(response.resumption_token and not response.resumption_token.empty?)
            puts "\nresumption token recieved, continuing" if @interactive
            response = client.list_records(:resumption_token => 
              response.resumption_token)
              get_records(response.doc).each do |rec|
                gz << rec
                records += 1
              end
            puts "#{records} records retrieved" if @interactive
          end

            gz << "</records>"
            
        ensure
          gz.close
          file.close
        end

        [file, records]
      end
    
      def get_records(doc)
        doc.find("/OAI-PMH/ListRecords/record").to_a
      end
    
      def build_options_hash(site)
        options = {:url => site['url']}
        options[:set] = site['set'] if site['set']
        options[:from] = site['last'].utc.xmlschema if site['last']
        options[:metadata_prefix] = site['prefix'] if site['prefix']
        options
      end
    
      def date_based_directory(time)
        "#{time.strftime(DIRECTORY_LAYOUT)}"
      end

      def filename(from_time, until_time)
        format = "%Y-%m-%d"
        "#{from_time.strftime(format)}_til_#{until_time.strftime(format)}"\
        "_at_#{until_time.strftime('%H-%M-%S')}"
      end
    
      # Get earliest timestamp from repository
      def earliest(url)
        client = OAI::Client.new url
        identify = client.identify
        Time.parse(identify.earliest_datestamp).utc.xmlschema
      end
    
    end
  
  end
end