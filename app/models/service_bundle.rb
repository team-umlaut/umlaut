class ServiceBundle
  attr_accessor :services
  attr_accessor :debugging
  
  def initialize(service_objects)
    @services = service_objects

    # Don't forward exceptions, that'll interrupt other service processing.
    # Catch the exception, record it in the dispatch table, done. May want
    # to set this to true for debugging/development, but NOT for production.
    @forward_exceptions = false
  end

  def handle(request)
    
    return if (@services.nil? || @services.empty?)
    threads = []
    @services.each do | service |
        #RAILS_DEFAULT_LOGGER.debug("Starting service #{service.id}")

        # Double check it's not already been run by somebody else, for
        # instance if this is a browser re-load. Skip it before
        # we even create a thread for it.
        next unless request.can_dispatch?(service)
        
        threads << Thread.new(request.id, service.clone) do | t_request_id, t_service |
        begin
          # Reload the request, to make sure we have our own copy, not
          # shared with other threads. A bit inefficient, but we help
          # by pre-loading what we can. Sadly, no way to pre-load
          # referent.referent_values that I can find. 
          t_request = Request.find( t_request_id , :include => [:referent, :referrer, :service_types, :dispatched_services])

          if ( t_request.can_dispatch?(t_service) )
            # Mark this service as in progress in the dispatch table.
            t_request.dispatched( t_service, DispatchedService::InProgress )
          
            # and actually execute it
            t_service.handle(t_request)
          end
          
        rescue Exception => e
          # Thread exception raising is weird, so we catch it inside
          # the thread, make the service a failure, and save
          # the exception in case we want it later!
          t_request.dispatched(service, DispatchedService::FailedFatal, e)
          # Log it too
          RAILS_DEFAULT_LOGGER.error("ERROR: Threaded service raised exception. Service: #{service.id}, #{e}, #{e.backtrace.join("\n")}")
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