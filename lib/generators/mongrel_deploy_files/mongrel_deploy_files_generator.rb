class MongrelDeployFilesGenerator < Rails::Generator::Base
  DEFAULT_NUM_MONGRELS = 4
  DEFAULT_START_PORT = 4001
  DEFAULT_USER = 'umlaut'
  DEFAULT_GROUP = 'umlaut'
  DEFAULT_IP = '0.0.0.0'
  DEFAULT_PREFIX = '/'
  
  default_options :num_mongrels => DEFAULT_NUM_MONGRELS, :start_port => DEFAULT_START_PORT, :user=>DEFAULT_USER, :group=>DEFAULT_GROUP, :ip => DEFAULT_IP, :web_prefix => DEFAULT_PREFIX
  
  def manifest
    record do |m|
      m.directory("config/umlaut_config/deploy")
      
      m.template("mongrel_cluster.yml", "config/umlaut_config/deploy/mongrel_cluster.yml", :assigns => options )

      m.template("umlaut_http.conf", "config/umlaut_config/deploy/umlaut_http.conf", :assigns => options )

      # Giving owner rwx and group rx, nothing for other. 
      m.template("my_mongrel_ctl", "script/umlaut/my_mongrel_ctl", :assigns => options, :chmod => 0750 )
     
    end
  end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("-n", "--num-mongrels=num", Integer,
             "Internal port to start first mongrel on.",
             "Default: #{DEFAULT_NUM_MONGRELS}") { |v| options[:num_mongrels] = v }
      opt.on("-b", "--start-port=port", Integer,
             "Internal port to start first mongrel on.",
             "Default: #{DEFAULT_START_PORT}") { |v| options[:start_port] = v }
      opt.on("-u", "--user=username", String,
             "Unix user to run mongrels under",
             "Default: #{DEFAULT_USER}") { |v| options[:user] = v }
      opt.on("-z", "--group=groupname", String,
             "Unix group to run mongrels under",
             "Default: #{DEFAULT_GROUP}") { |v| options[:group] = v }
      opt.on("-a", "--ip-addr=addr", String,
             "IP address to bind mongrels to",
             "Default: #{DEFAULT_IP} (0.0.0.0 means server default IP)") { |v| options[:ip] = v }
      # prefix must begin with a '/' and not end with one, fix it. 
      opt.on("-x", "--prefix=prefix", String, "Web path prefix to install mongrels into.", "Default: #{DEFAULT_PREFIX}") do |v|
        v.chop! if v[v.length-1,1] == '/'
        v = '/' + v unless v[0,1] == '/'
        options[:web_prefix] = v
      end
    end
end

