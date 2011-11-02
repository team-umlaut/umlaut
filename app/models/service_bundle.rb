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
    @forward_exceptions = true
  end
  
  # Safe to call in a thread. Returns true or false depending on
  # whether dispatch should proceed. 
  def prepare_dispatch!(request, service, session_id)
    can_dispatch = false
    
    ActiveRecord::Base.connection_pool.with_connection do
      if request.can_dispatch?( service)
        # Mark this service as in progress in the dispatch table.
        request.dispatched( service, DispatchedService::InProgress )
        # remember the rails session id. 
        service.session_id = session_id
        
        can_dispatch = true      
      end
    end
    return can_dispatch
  end

  def handle(request, session_id)
    return if (@services.nil? || @services.empty?)

    bundle_start = Time.now
    Rails.logger.info("Launching servicelevel #{@priority_level}, request #{request.id}") if @log_timing

    
    threads = []
    some_service_executed = false
    @services.each do | service |
        some_service_executed = true
        
        # Make a proc for the actual service execution, then we'll
        # execute it either in a thread or not, depending on settings.
        service_execute = Proc.new do | local_request, local_service|
          begin
            service_start = Time.now            
  
            if prepare_dispatch!(local_request, local_service, session_id)                          
              local_service.handle_wrapper(local_request)
            else
              Rails.logger.info("NOT launching service #{local_service.service_id},  level #{@priority_level}, request #{local_request.id}: not in runnable state") if @log_timing
            end
            
           
          rescue ActiveRecord::ImplicitConnectionForbiddenError => e
            # connection forbidden raised by our patch that forces explicit
            # checkout of AR connection in threads. We rescue special
            # because we can't use any AR methods in our rescue! 
            Thread.current[:exception] = e
          rescue Exception => e
            # we're still in a thread here, need to checkout
            ActiveRecord::Base.connection_pool.with_connection do
              # Thread exception raising is weird, so we catch it inside
              # the thread, make the service a failure, and save
              # the exception in case we want it later!
              local_request.dispatched(service, DispatchedService::FailedFatal, e)
              # Log it too, although experience shows it may never make it to the 
              # log since our thread is dying hard, oh well. 
              Rails.logger.error("Threaded service raised exception. Service: #{service.service_id}, #{e}, #{e.backtrace.join("\n")}")
              # And stick it in a thread variable too
              Thread.current[:exception] = e
            end
          ensure
            Rails.logger.info("Completed service #{local_service.service_id},  level #{@priority_level}, request #{local_request.id}: in #{Time.now - service_start}.") if @log_timing
          end
        end
        
        if ( @use_threads )        
          threads << Thread.new(request.id, service.clone) do | request_id, t_service |            
            # Tell our AR extension not to allow implicit checkouts
            ActiveRecord::Base.forbid_implicit_checkout_for_thread! 
            
            Thread.current[:debug_name] = t_service.class.name
            
            t_request = ActiveRecord::Base.connection_pool.with_connection do
              # pre-load all relationships so no ActiveRecord activity will be
              # needed later to see em. 
              Request.includes(:referrer, :referent, :service_types, :dispatched_services).find(request_id)
            end
            
          
              
            # Deal with ruby's brain dead thread scheduling by setting
            # bg threads to a lower priority so they don't interfere with fg
            # threads.
            Thread.current.priority = -1
          
            service_execute.call(t_request, t_service)
          end
        else
          service_execute.call( request, service)
        end
    end

    # Wait for all the threads to complete, if any. 
    threads.each { |aThread|
      
      aThread.join
      debugger if aThread[:exception]

      aThread.kill # shouldn't be neccesary, but I'm paranoid
      # Okay, raise if exception, if desired.
      
      if ( aThread[:exception] && (self.forward_exceptions? || aThread[:exception].kind_of?(ActiveRecord::ImplicitConnectionForbiddenError)))
        raise aThread[:exception]
      end
    }
    
    threads.clear # more paranoia
    
    # AR opens a db connection per thread, and never ever
    # closes it. But this entirely undocumented method will
    # close connections associated with finished threads, hooray!
    ActiveRecord::Base.verify_active_connections!()

    Rails.logger.info("Completed services level #{@priority_level}, request #{request.id}: in #{Time.now - bundle_start}") if some_service_executed && @log_timing
  end

  def forward_exceptions?
    return @forward_exceptions
  end
  def forward_exceptions=(f)
    @foward_excpetions = f    
  end
end