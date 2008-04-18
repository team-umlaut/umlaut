class ServiceBundle
  attr_accessor :services
  attr_accessor :priority_level

  # Priority level is purely information, used for debug output. 
  def initialize(service_objects, priority_level = nil)
    @services = service_objects
    @priority_level = priority_level

    @log_timing = AppConfig.param("log_service_timing", true)
    @use_threads = AppConfig.param("threaded_services", true)

    # Don't forward exceptions, that'll interrupt other service processing.
    # Catch the exception, record it in the dispatch table, done. May want
    # to set this to true for debugging/development, but NOT for production.
    @forward_exceptions = false
  end

  def handle(request)
    
    return if (@services.nil? || @services.empty?)

    bundle_start = Time.now
    
    threads = []
    some_service_executed = false
    @services.each do | service |
        # Double check it's not already been run by somebody else, for
        # instance if this is a browser re-load. Skip it before
        # we even create a thread for it.
        next unless request.can_dispatch?(service)
        some_service_executed = true
        
        # Make a proc for the actual service execution, then we'll
        # execute it either in a thread or not, depending on settings.
        service_execute = Proc.new do | local_request_id, local_service|
          begin
            service_start = Time.now
            
            # Reload the request, to make sure we have our own copy, not
            # shared with other threads. A bit inefficient, but we help
            # by pre-loading what we can. Sadly, no way to pre-load
            # referent.referent_values that I can find. 
            local_request = Request.find( local_request_id , :include => [:referent, :referrer, :service_types, :dispatched_services])
  
            if ( local_request.can_dispatch?(local_service) )
              # Mark this service as in progress in the dispatch table.
              local_request.dispatched( local_service, DispatchedService::InProgress )
            
              # and actually execute it
              local_service.handle(local_request)
            end
            
          rescue Exception => e
            # Thread exception raising is weird, so we catch it inside
            # the thread, make the service a failure, and save
            # the exception in case we want it later!
            local_request.dispatched(service, DispatchedService::FailedFatal, e)
            # Log it too
            RAILS_DEFAULT_LOGGER.error("Threaded service raised exception. Service: #{service.id}, #{e}, #{e.backtrace.join("\n")}")
            # And stick it in a thread variable too
            Thread.current[:exception] = e
          ensure
            RAILS_DEFAULT_LOGGER.info("Completed service #{local_service.id},  level #{@priority_level}, request #{local_request_id}: in #{Time.now - service_start}.") if @log_timing
          end
        end
        
        if ( @use_threads )        
          threads << Thread.new(request.id, service.clone) do | t_request_id, t_service |
             service_execute.call(t_request_id, t_service)
          end
        else
          service_execute.call( request.id, service)
        end
    end

    # Wait for all the threads to complete, if any. 
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

    RAILS_DEFAULT_LOGGER.info("Completed services level #{@priority_level}, request #{request.id}: in #{Time.now - bundle_start}") if some_service_executed && @log_timing
  end

  def forward_exceptions?
    return @forward_exceptions
  end
  def forward_exceptions=(f)
    @foward_excpetions = f    
  end
end