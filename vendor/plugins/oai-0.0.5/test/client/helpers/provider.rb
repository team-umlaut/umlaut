require 'webrick'
require File.dirname(__FILE__) + '/../../provider/models'

class ComplexProvider < OAI::Provider::Base
  repository_name 'Complex Provider'
  repository_url 'http://localhost'
  record_prefix 'oai:test'
  source_model ComplexModel.new(100)
end

class ProviderServer < WEBrick::HTTPServlet::AbstractServlet
  @@server = nil
  
  def initialize(server)
    super(server)
    @provider = ComplexProvider.new
  end
  
  def do_GET(req, res)
    begin
      res.body = @provider.process_request(req.query)
      res.status = 200
      res['Content-Type'] = 'text/xml'
    rescue => err
      puts err
      puts err.backtrace.join("\n")
      res.body = err.backtrace.join("\n")
      res.status = 500
    end
  end
  
  def self.start(port)
    unless @@server
      @@server = WEBrick::HTTPServer.new(
        :BindAddress => '127.0.0.1', 
        :Logger => WEBrick::Log.new('/dev/null'),
        :AccessLog => [],
        :Port => port)
      @@server.mount("/oai", ProviderServer)

      trap("INT") { @@server.shutdown }
      @@thread = Thread.new { @@server.start }
      puts "Starting Webrick/Provider on port[#{port}]"
    end
  end
  
  def self.stop
    puts "Stopping Webrick/Provider"
    if @@thread
      @@thread.exit
    end
  end
  
  def self.wrap(port = 3333)
    begin
      start(port)

      # Wait for startup
      sleep 2
    
      yield

    ensure
      stop
    end
  end
  
end
