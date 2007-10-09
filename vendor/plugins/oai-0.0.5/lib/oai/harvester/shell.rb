module OAI
  module Harvester
    # = OAI::Harvester::Shell
    # 
    # A OAI-PMH client shell allowing OAI Harvesting to be configured in
    # an interactive manner.  Typing 'oai' on the command line starts the
    # shell.  The first time the shell is run it will prompt for the following
    # configuration details:
    # 1. A storage directory for all harvested records.  Harvests will be 
    #    stored under this directory in a directory structure based on the 
    #    date of the harvest.
    # 2. A log file directory.
    # 3. Email address(es) for sending daily harvesting activity reports.
    # 4. Network address of the SMTP server for sending mail.
    #
    # After the initial configuration, new harvest sites can be added by using
    # the 'new' command.  Sites are identified via nickname assigned by the
    # user.  After choosing a nickname, provide the URL of a harvestable site,
    # and the shell will prompt you for the rest of the configuration
    # information.
    #
    # The shell automatically pulls down the list of sets in the repository, and
    # the supported metadata prefixes.  Making it very simple to setup harvests.
    #  
    class Shell
      include Readline
    
      def initialize(config)
        @conf = config
        @conf.sites ||= {} # Initialize sites hash there isn't one
      end
    
      def start
        unless @conf.storage
          banner "Entering first-time setup"
          config
          setup_cron
        end
        puts "type 'help' for help"
        while((input = readline("oai> ", true)) != 'exit')
          begin
            cmd = input.split
            if 1 == cmd.size
              self.send(cmd[0])
            else
              self.send(cmd.shift, cmd.join(" "))
            end
          rescue 
            puts "Not a recognized command, or bad options.  Type 'help' for clues."
            #puts $!
            #puts $!.backtrace.join("\n")
          end
        end
      end
    
      private
    
      def help
        banner "Commands:"
        puts "\tharvest site [date]     - Harvest site(s) manually"
        puts "\tconfig                  - Configure harvester"
        puts "\tlist <config>           - List known providers or configuration"
        puts "\tinfo [site[, site]]     - Show information about a provider."
        puts "\tnew                     - Add a new provider site to harvester"
        puts "\tremove [site]           - Remove a provider site from harvester"
        puts "\tedit [site]             - Change settings for a provider site"
        puts "\texit                    - Exit the harvester shell.\n\n"
      end
    
      def harvest(options)
        site, *date = options.split(/\s/)
        if @conf.sites.keys.include?(site)
            banner "Harvesting '#{site}'"
            if date && !date.empty?
              begin
                date = Chronic.parse(date.join(' ')).utc.xmlschema
              rescue NoMethodError
                puts "Couldn't parse the date supplied"
                return
              end
            else 
              date = nil
            end
            harvester = Harvest.new(@conf, @conf.storage, date)
            harvester.start(site, true)
            puts "done"
        else
          puts "Unknown repository: '#{args[0]}'"
        end
        puts # blank line
      end
    
      def list(args = nil)
        if 'config' == args
          banner "Current Configuration"
          list_config
        else
          banner "Configured Repositories"
          @conf.sites.keys.each do |k|
            puts k
          end
        end
        puts # blank line
      end
    
      def info(args)
        banner "Provider Site Information"
        sites = args.split(/[,\s|\s|,]/)
        sites.each do |site|
          print_site(site)
        end
        puts
      end
    
      def new
        banner "Define New Harvesting Site"
        name, site = form
        @conf.sites[name] = site
        @conf.save
      end
    
      def edit(name)
        banner "Edit Harvesting Site"
        name, site = form(name)
        @conf.sites[name] = site
        @conf.save
      end
    
      def remove(site)
        if 'Y' == readline("Remove #{site}? (Y/N): ").upcase
          @conf.sites.delete(site)
          @conf.save
          puts "#{site} removed"
        end
      end

      # http://oai.getty.edu:80/oaicat/OAIHandler
      def form(name = nil)
        begin
          if not name
            name = prompt("nickname", nil)
            while(@conf.sites.keys.include?(name))
              show 0, "Nickname already in use, choose another."
              name = prompt("nickname")
            end
          end
          site = @conf.sites[name] || {}
      
          # URL
          url = prompt("url", site['url'])
          while(not (site['url'] = verify(url)))
            puts "Trouble contacting provider, bad url?"
            url = prompt("url", site['url'])
          end
      
          # Metadata formats
          formats = metadata(site['url'])
          report "Repository supports [#{formats.join(', ')}] metadata formats."
          prefix = prompt("prefix", site['prefix'])
          while(not formats.include?(prefix))
            prefix = prompt("prefix", site['prefix'])
          end
          site['prefix'] = prefix

          # Sets
          sets = ['all']
          begin
            sets.concat sets(site['url'])
            site['set'] = 'all' unless site['set'] # default to all sets
            report "Repository supports [#{sets.join(', ')}] metadata sets."
            set = prompt("set", site['set'])
            while(not sets.include?(site['set']))
              set = prompt("set", site['set'])
            end
            site['set'] = set
          rescue
            site['set'] = 'all'
          end

          # Period
          period = expand_period(prompt("period", "daily"))
          while(not Config::PERIODS.include?(period))
            puts "Must be daily, weekly, or monthly"
            period = expand_period(prompt("period", "daily"))
          end
      
          site['period'] = period
      
          return [name, site]
        rescue 
          puts "Problem adding/updating provider, aborting. (#{$!})"
        end
      end
    
      def config
        begin
          directory = prompt("storage directory", @conf.storage)
          while not directory_acceptable(directory)
            directory = prompt("storage directory: ", @conf.storage)
          end

          email = @conf.email.join(', ') rescue nil
          @conf.email = parse_emails(prompt("email", email))
        
          @conf.mail_server = prompt("mail server", @conf.mail_server)

          logfile = prompt("log file(s) directory", @conf.logfile)
          while not directory_acceptable(logfile)
            logfile = prompt("log file(s) directory", @conf.logfile)
          end
          @conf.storage = directory
          @conf.logfile = logfile
          @conf.save
        rescue 
          nil
        end
      end
        
      def display(key, value, split = 40)
        (split - key.size).times { print " " } if key.size < split
        puts "#{key}: #{value}"
      end
    
      def banner(str)
        puts "\n#{str}"
        str.size.times { print "-" }
        puts "\n"
      end
      
      def report(str)
        puts "\n#{str}\n"
      end

      def indent(number)
        number.times do
          print "\t"
        end
      end
    
      def prompt(text, default = nil, split = 20)
        prompt_text = "#{text} [#{default}]: "
        (split - prompt_text.size).times { print " " } if prompt_text.size < split
        value = readline(prompt_text, true)
        raise RuntimeError.new("Exit loop") unless value
        return value.empty? ? default : value
      end
    
      def verify(url)
        begin
          client = OAI::Client.new(url, :redirects => false)
          identify = client.identify
          puts "Repository name \"#{identify.repository_name}\""
          return url
        rescue
          if $!.to_s =~ /^Permanently Redirected to \[(.*)\?.*\]/
            report "Provider redirected to: #{$1}"
            verify($1)
          else
            puts "Error selecting repository: #{$!}"
          end
        end
      end
    
      def metadata(url)
        formats = []
        client = OAI::Client.new url
        response = client.list_metadata_formats
        response.to_a.each do |format|
          formats << format.prefix
        end
        formats
      end
      
      def sets(url)
        sets = []
        client = OAI::Client.new url
        response = client.list_sets
        response.to_a.each do |set|
          sets << set.spec
        end
        sets
      end

      def directory_acceptable(dir)
        if not (dir && File.exists?(dir) && File.writable?(dir))
          puts "Directory doesn't exist, or isn't writtable."
          return false
        end
        true
      end
    
      def expand_period(str)
        return str if Config::PERIODS.include?(str)
        Config::PERIODS.each { |p| return p if p =~ /^#{str}/}
        nil
      end
    
      def parse_emails(emails)
        return nil unless emails
        addresses = emails.split(/[,\s|\s|,]/)
      end
        
      def list_config
        display("storage directory", @conf.storage, 20)
        display("email", @conf.email.join(', '), 20) if @conf.email
        display("mail server", @conf.mail_server, 20) if @conf.mail_server
        display("log location", @conf.logfile, 20) if @conf.logfile
      end
    
      def list_sites
        banner "Sites"
        @conf.sites.each_key { |site| print_site(site) }
      end
    
      def print_site(site)
        puts site
        @conf.sites[site].each { |k,v| display(k, v, 15)}
      end
    
      def setup_cron
        banner "Scheduling Automatic Harvesting"
        puts "To activate automatic harvesting you must add an entry to"
        puts "your scheduler.  Linux/Mac OS X users should add the following"
        puts "entry to their crontabs:\n\n"
        puts "0 0 * * * #{$0} -D\n\n"
        puts "Windows users should use WinAt to schedule"
        puts "#{$0} to run every night.\n\n\n"
      end
    
    end

  end
end        
      
