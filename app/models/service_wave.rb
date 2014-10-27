require 'term_color'

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
  def prepare_dispatch!(request, service)            
    return request.register_in_progress(service)                    
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
              # We are attempting to pre-load all relationships, both for efficiency,
              # and so our thread can use them all without needing to checkout
              # an ActiveRecord connection. 
              req = Request.includes({:referent => :referent_values}, :service_responses, :dispatched_services).find(request_id)

              # It turns out even though referent.referent_values is loaded from the db, on first
              # access Rails will still access #connection, triggering a checkout. We force
              # that to happen here, in our with_connection, so it won't happen later. 
              #
              # Yeah, this is a hacky mess, ActiveRecord isn't happy using it the way we are. 
              # Should we just surround all of handle_wrapper in a with_connection checkout?
              # Maybe. But it would require more connections in the pool to have those
              # longer checkouts. 
              req.referent.referent_values
              req.service_responses
              req.dispatched_services

              req
            end

              
  
            if prepare_dispatch!(local_request, local_service)
              local_service.handle_wrapper(local_request)
            else
              Rails.logger.info("NOT launching service #{local_service.service_id},  level #{@priority_level}, request #{local_request.id}: not in runnable state") if @log_timing
            end
            
           
          rescue StandardError => e
            # We may not be able to access ActiveRecord because it may
            # have been an AR connection error, perhaps out of connections
            # in the pool. So log and record in non-AR ways. 
            # the code waiting on our thread will see exception
            # reported in Thread local var, and log it AR if possible. 
            
            
            # Log it too, although experience shows it may never make it to the 
            # log for mysterious reasons. 
            log_msg = TermColor.color("Umlaut: Threaded service raised exception.", :red, true) + " Service: #{service.service_id}, #{e.class} #{e.message}. Backtrace:\n  #{clean_backtrace(e).join("\n  ")}"
            Rails.logger.error(log_msg)
            
            # And stick it in a thread variable too
            Thread.current[:exception] = e    

            # And try to re-raise if it's one we really don't want to swallow. 
            # Sorry, a mess. 
            raise e if defined?(VCR::Errors::UnhandledHTTPRequestError) && e.kind_of?(VCR::Errors::UnhandledHTTPRequestError)
          ensure
            Rails.logger.info(TermColor.color("Umlaut: Completed service #{local_service.service_id}", :yellow)+ ",  level #{@priority_level}, request #{local_request && local_request.id}: in #{Time.now - service_start}.") if @log_timing
          end
        end
      else # not threaded
        begin
          if prepare_dispatch!(request, service)
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
        debugger if ENV["UMLAUT_AUTO_DEBUGGER"]
        begin
          request.dispatched(aThread[:service], DispatchedService::FailedFatal, aThread[:exception])
        rescue Exception => e
          debugger if ENV["UMLAUT_AUTO_DEBUGGER"]
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
    def clean_backtrace(exception)
      Umlaut::Util.clean_backtrace(exception)
    end

  
end
