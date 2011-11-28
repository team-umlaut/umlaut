require 'CronTab' # for understanding CronTab format for expiring responses. 

# A Collection object encapsulates a given UmlautRequest, and a given
# list of Umlaut services that should be run off that request.
#
# That's exactly what it's initialized with: an umlaut request, and
# list of service definitions. Third parameter pass in an umlaut configuration
# object, to get various timeout values. If you don't pass one in, defaults
# will be used. 
#
# The Collection holds and executes the logic for running those services, 
# foreground and background, making sure no service is run twice if it's
# already in progress, timing out expired services, etc. 
class Collection
  
  attr_accessor :umlaut_request
  attr_accessor :logger
  # configs
  attr_accessor :response_expire_interval, :response_expire_crontab_format, :background_service_timeout, :requeue_failedtemporary_services
  
   
  def initialize(a_umlaut_request, service_hash, config = Confstruct::Configuration.new)    
    self.umlaut_request = a_umlaut_request
    
    self.logger = Rails.logger
    
    self.response_expire_interval = config.lookup!("response_expire_interval", 1.day)
    self.response_expire_crontab_format = config.lookup!("response_expire_crontab_format", nil)
    self.background_service_timeout =  config.lookup!("background_service_timeout", 30.seconds)
    self.requeue_failedtemporary_services = config.lookup!("requeue_failedtemporary_services", 500.seconds)
        
    # @service_definitions will be a two-level hash, pointing to an array.. Task is Standard, LinkOut, etc.
    # { [task] => { [priority_level] => [config1, config2, config3],
    #                [priority_level_2] => [configa], }
    #     [...]
    # }
    @service_definitions_flat = service_hash
    @service_definitions = {}

    # Arrange services by type and priority in @service_definitions     
    gather_services
  end

  # Starts running all services that are in this collection, for the given
  # request set for this collection, if and only if they are not already
  # in progress.
  #
  # This method can be run on a request multiple times, it'll only re-execute
  # services that are executable (not already running, or timed out). 
  # That characteristic is used when this method is called on a page refresh
  # or background update status check.   
  #
  # Sets all services in collection to have a 'queued' status if appropriate.
  # Then actually executes the services that are dispatchable (queued).    
  def dispatch_services!
    # Go through currently dispatched services, looking for timed out
    # services -- services still in progress that have taken too long,
    # as well as service responses that are too old to be used.      
    umlaut_request.dispatched_services.each do | ds |
        # go through dispatched_services and set stil in progress but too long to failed temporary
        if ( (ds.status == DispatchedService::InProgress ||
              ds.status == DispatchedService::Queued ) &&
              (Time.now - ds.updated_at) > self.background_service_timeout)

              ds.store_exception( Exception.new("background service timed out (took longer than #{self.background_service_timeout} to run); thread assumed dead.")) unless ds.exception_info
              # Fail it temporary, it'll be run again. 
              ds.status = DispatchedService::FailedTemporary
              ds.save!
              logger.warn("Background service timed out, thread assumed dead. #{umlaut_request.id} / #{ds.service_id}")
         end
         
        # go through dispatched_services and delete:
        # 1) old completed dispatches, too old to use. 
        # 2) failedtemporary dispatches that are older than our resurrection time
        # -> And all responses associated with those dispatches. 
        # After being deleted, they'll end up re-queued. 
        if ( (ds.completed? && completed_dispatch_expired?(ds) ) ||
             (  ds.status == DispatchedService::FailedTemporary &&
               (Time.now - ds.updated_at) > self.requeue_failedtemporary_services 
              )
            )
            
          # Need to expire. Delete all the service responses, and
          # the DispatchedService record, and service will be automatically
          # run again.
          serv_id = ds.service_id
          
          umlaut_request.service_responses.each do |response|            
            if response.service_id == serv_id
              umlaut_request.service_responses.delete(response)              
              response.destroy
            end
          end
          
          umlaut_request.dispatched_services.delete(ds)
          ds.destroy
        end
    end
        
    # Queue any services without a dispatch marker at all, keeping
    # track of queued services, already existing or newly created. 
    
    # Just in case, we're going to refetch dispatched_services from the db,
    # in case some other http request or background service updated things
    # recently. 
    umlaut_request.dispatched_services.reset
    
    queued_service_ids = []
    self.get_service_definitions.each do |service|
      service_id = service['service_id']
      # use in-memory #to_a search, don't go to db each time!
      if found = umlaut_request.dispatched_services.to_a.find {|s| s.service_id == service_id}
        queued_service_ids.push(service_id) if found.status == DispatchedService::Queued
      else
        umlaut_request.new_dispatch_object!(service_id, DispatchedService::Queued).save!
        queued_service_ids.push(service_id)
      end        
    end
    

    
    # Now actually dispatch. 
    
    # Foreground services
    (0..9).each do | priority |      
      services_to_run = self.instantiate_services!(:level => priority, :ids => queued_service_ids)
      next if services_to_run.empty?      
      ServiceWave.new(services_to_run , priority).handle(umlaut_request, umlaut_request.session_id)
    end
    
    # Need to reload the request from db, so it gets changes
    # made by services in threads. 
    umlaut_request.reload
    
    # Now we run background services.
    # Now we do some crazy magic, start a Thread to run our background
    # services. We are NOT going to wait for this thread to join,
    # we're going to let it keep doing it's thing in the background after
    # we return a response to the browser
    backgroundThread = Thread.new(self, umlaut_request) do | t_collection,  t_request|
      # Tell our AR extension not to allow implicit checkouts
      ActiveRecord::Base.forbid_implicit_checkout_for_thread! if ActiveRecord::Base.respond_to?("forbid_implicit_checkout_for_thread!")
      
      # got to reserve an AR connection for our main 'background traffic director'
      # thread, so it has a connection to use to mark services as failed, at least. 
      ActiveRecord::Base.connection_pool.with_connection do
        begin
          # Deal with ruby's brain dead thread scheduling by setting
          # bg threads to a lower priority so they don't interfere with fg
          # threads.
          Thread.current.priority = -1          
        
          ('a'..'z').each do | priority |
            services_to_run = self.instantiate_services!(:level => priority, :ids => queued_service_ids)        
            next if services_to_run.empty?      
            ServiceWave.new(services_to_run , priority).handle(umlaut_request, umlaut_request.session_id)                               
          end        
       rescue Exception => e
         #debugger
          # We are divorced from any request at this point, not much
          # we can do except log it. Actually, we'll also store it in the
          # db, and clean up after any dispatched services that need cleaning up.
          # If we're catching an exception here, service processing was
          # probably interrupted, which is bad. You should not intentionally
          # raise exceptions to be caught here.
          Thread.current[:exception] = e
          logger.error("Background Service execution exception1: #{e}\n\n   " + clean_backtrace(e).join("\n"))                
       end
     end
    end

    
    
  end
  
  def completed_dispatch_expired?(ds)
    interval = self.response_expire_interval
    crontab = self.response_expire_crontab_format
    now = Time.now
    
    return nil unless interval || crontab 
    
    expired_interval = interval && (now - ds.created_at > interval)
    expired_crontab = crontab && (now > CronTab.new(crontab).nexttime(ds.created_at))
    
    return expired_interval || expired_crontab
  end
  
  
  

  # Instantiate new copies of services included in this collection, which
  # services specified by options, can combine:
  # :task => Service::StandardTask (default) or Service::LinkOutFilterTask
  # :level => priority level, default to returning services from all.
  # :ids => list of id's, only those. 
  def instantiate_services!(options ={})
    get_service_definitions(options).collect do |svc_def|
      ServiceStore.instantiate_service!(svc_def, umlaut_request)
    end
  end
      

  # Deprecated, use #instantiate_services! with :task => Service::LinkOutFilter.
  def link_out_service_level(level)
    instantiate_services!(:task => Service::LinkOutFilterTask, 
                          :level => level)
  end

  

  # Get service definition hashes for services in this institution.
  # options, returned in an array. 
  # Does return a mutatable array that Collection mutates
  # internally, but clients really ought not to mutate. 
  # :task => Service::StandardTask (default) or Service::LinkOutFilterTask
  # :level => priority level, default to returning services from all. 
  # :ids => list of service unique ids, return only these. 
  def get_service_definitions(options = {})
    options[:task] ||= Service::StandardTask
    
    configs_for_task = @service_definitions[ options[:task] ] || {}
    
    service_configs = case options[:level]
                        when nil
                          # All of of them for this task
                          configs_for_task.values.flatten
                        else
                          configs_for_task[ options[:level] ] || []
                      end
     if options[:ids]
       service_configs = service_configs.find_all {|s| options[:ids].include? s["service_id"] }
     end
                                                      
     return service_configs 
  end

  protected
  
  # Arrange services in hash according to task type and priority. 
  def gather_services
    @service_definitions_flat.each_pair do | unique_id, svc_def |              
      svc_def['service_id'] = unique_id
      task = svc_def['task'] || Service::StandardTask
      level = svc_def['priority'] || 3
      
      @service_definitions[task] ||= {}
      @service_definitions[task][level] ||= []
      @service_definitions[task][level] << svc_def                              
    end          
  end

  
  


end
