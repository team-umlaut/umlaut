# ServiceWave is basically responsible for multi-threaded execution of
# a list of services, all in the same priority. Generally it's only
# called by Collection, nobody else needs it directly. 
#
class ServiceWave
  attr_accessor :services
  attr_accessor :priority_level
  attr_reader :config

  # Priority level is purely information, used for debug output. 
  def initialize(service_objects, priority_level = nil, config = UmlautController.umlaut_config)
    @services = service_objects
    @priority_level = priority_level
    @config = config
    @log_timing = config.lookup!("log_service_timing", true)

    # Don't forward exceptions, that'll interrupt other service processing.
    # Catch the exception, record it in the dispatch table, done. May want
    # to set this to true for debugging/development, but NOT for production.
    @forward_exceptions = false
  end
  
  # Safe to call in a thread. Returns true or false depending on
  # whether dispatch should proceed. 
  def prepare_dispatch!(request, service, session_id)
    can_dispatch = false
    
    Request.connection_pool.with_connection do
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
    Rails.logger.info(TermColor.color("Umlaut: Launching service wave #{@priority_level} #{'(non-threaded)' unless config.lookup!("threaded_service_wave", true) }", :yellow) + ", request #{request.id}") if @log_timing

    
    
    threads = []
    some_service_executed = false
    @services.each do | service |
      some_service_executed = true
      local_request = nil
      
      service_start = Time.now          

      if config.lookup!("threaded_service_wave", true)

      
        threads << Thread.new(request.id, service.clone) do | request_id, local_service |
          # Deal with ruby's brain dead thread scheduling by setting
          # bg threads to a lower priority so they don't interfere with fg
          # threads.
          Thread.current.priority = -1
  
          # Save some things in thread local hash useful for debugging
          Thread.current[:debug_name] = local_service.class.name
          Thread.current[:service] = service
  
          # Tell our AR extension not to allow implicit checkouts
          ActiveRecord::Base.forbid_implicit_checkout_for_thread! if ActiveRecord::Base.respond_to?("forbid_implicit_checkout_for_thread!")
          
          begin
            local_request = Request.connection_pool.with_connection do
              # pre-load all relationships so no ActiveRecord activity will be
              # needed later to see em. 
              Request.includes(:referent, :service_responses, :dispatched_services).find(request_id)
            end
            
  
            if prepare_dispatch!(local_request, local_service, session_id)                          
              local_service.handle_wrapper(local_request)
            else
              Rails.logger.info("NOT launching service #{local_service.service_id},  level #{@priority_level}, request #{local_request.id}: not in runnable state") if @log_timing
            end
            
           
          rescue Exception => e
            # We may not be able to access ActiveRecord because it may
            # have been an AR connection error, perhaps out of connections
            # in the pool. So log and record in non-AR ways. 
            # the code waiting on our thread will see exception
            # reported in Thread local var, and log it AR if possible. 
            
            
            # Log it too, although experience shows it may never make it to the 
            # log for mysterious reasons. 
            Rails.logger.error(TermColor.color("Umlaut: Threaded service raised exception.", :red, true) + " Service: #{service.service_id}, #{e.class} #{e.message}\n  #{clean_backtrace(e).join("\n  ")}")
            
            # And stick it in a thread variable too
            Thread.current[:exception] = e                      
          ensure
            Rails.logger.info(TermColor.color("Umlaut: Completed service #{local_service.service_id}", :yellow)+ ",  level #{@priority_level}, request #{local_request && local_request.id}: in #{Time.now - service_start}.") if @log_timing
          end
        end
      else # not threaded
        begin
          if prepare_dispatch!(request, service, session_id)                          
              service.handle_wrapper(request)
          else
              Rails.logger.info("NOT launching service #{service.service_id},  level #{@priority_level}, request #{request.id}: not in runnable state") if @log_timing
          end
        ensure
          Rails.logger.info(TermColor.color("Umlaut: Completed service #{service.service_id}", :yellow)+ ",  level #{@priority_level}, request #{request && request.id}: in #{Time.now - service_start}.") if @log_timing
        end
      end
      
    end

    # Wait for all the threads to complete, if any. 
    threads.each do |aThread|
      aThread.join

      if aThread[:exception] 
        debugger if Rails.env.development?
        begin
          request.dispatched(aThread[:service], DispatchedService::FailedFatal, aThread[:exception])
        rescue Exception => e
          debugger if Rails.env.development?
          raise e
        end
      end

      # Okay, raise if exception, if desired.
      if ( aThread[:exception] && self.forward_exceptions? )        
        raise aThread[:exception]
      end
    end

    threads.clear # more paranoia


    Rails.logger.info(TermColor.color("Umlaut: Completed service wave #{@priority_level}", :yellow) + ", request #{request.id}: in #{Time.now - bundle_start}") if some_service_executed && @log_timing
  end

  def forward_exceptions?
    return @forward_exceptions
  end
  def forward_exceptions=(f)
    @foward_excpetions = f    
  end
  
  protected
    def clean_backtrace(exception, *args)
      defined?(Rails) && Rails.respond_to?(:backtrace_cleaner) ?
        Rails.backtrace_cleaner.clean(exception.backtrace, *args) :
        exception.backtrace
    end

  
end
