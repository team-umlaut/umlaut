class ServiceBundle
  attr_accessor :services

  def initialize(service_objects)
    @services = service_objects

    @forward_exceptions = true
  end

  def handle(request)
    threads = []
    @services.each do | service |
      RAILS_DEFAULT_LOGGER.info("Starting service #{service.id}")
      threads << Thread.new(request.id, service.clone) do | t_request_id, t_service |
        begin
          # Reload the request, to make sure we have our own copy, not
          # shared with other threads. A bit inefficient, but we help
          # by pre-loading what we can. Sadly, no way to pre-load
          # referent.referent_values that I can find. 
          t_request = Request.find( t_request_id , :include => [:referent, :referrer, :service_types, :dispatched_services])
          
          t_service.handle(t_request) unless t_request.dispatched?( t_service )          
          
        rescue Exception => e
          # Thread exception raising is weird, so we catch it inside
          # the thread, make the service a failure, and save
          # the exception in case we want it later!
          request.dispatched(service, false, e)
          # Log it too
          RAILS_DEFAULT_LOGGER.error("ERROR: Threaded service raised exception. Service: #{service.id}, #{e}, #{e.backtrace.join("\n")}\n")
          # And stick it in a thread variable too
          Thread.current[:exception] = e
        end
      end
    end

    # Wait for all the threads to complete
    threads.each { |aThread|
      aThread.join
      aThread.kill # shouldn't be neccesary, but I'm paranoid
      # Okay, raise if exception, if desired. 
      if ( self.forward_exceptions? && aThread[:exception] )
        raise aThread[:exception]
      end
    }
    threads.clear # more paranoia
    
    # AR opens a db connection per thread, and never ever
    # closes it. But this entirely undocumented method will
    # close connections associated with finished threads, hooray!
    ActiveRecord::Base.verify_active_connections!()
  end

  def forward_exceptions?
    return @forward_exceptions
  end
  def forward_exceptions=(f)
    @foward_excpetions = f    
  end
end