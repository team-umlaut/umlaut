require 'cron_tab' # for understanding CronTab format for expiring responses.
require 'confstruct'

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
#
# This code is a mess, sorry. 
class Collection
  attr_accessor :umlaut_request
  attr_accessor :logger
  # configs
  attr_accessor :response_expire_interval, :response_expire_crontab_format, :background_service_timeout, :requeue_failedtemporary_services_in

  # generally only set to true in testing, can be set for the whole class
  # or for particular Collection instances. 
  class_attribute :forward_background_exceptions
  self.forward_background_exceptions = true
  
  # a_umlaut_request is an UmlautRequest, representing a request for services for a context
  # object.
  # service_hash is a hash of hashes with service definitions, as would
  # be in services.yml
  # config is a Confstruct::Configuration associated with the current controller,
  # has a few config options in it relevant to collection service exec; but
  # don't pass in, we'll use a blank one with default values, no prob.
  def initialize(a_umlaut_request, service_hash, config = Confstruct::Configuration.new) 
    self.umlaut_request = a_umlaut_request

    self.logger = Rails.logger

    self.response_expire_interval = config.lookup!("response_expire_interval", 1.day)
    self.response_expire_crontab_format = config.lookup!("response_expire_crontab_format", nil)
    self.background_service_timeout =  config.lookup!("background_service_timeout", 30.seconds)
    self.requeue_failedtemporary_services_in = config.lookup!("requeue_failedtemporary_services_in", 500.seconds)

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
  #
  # Returns the Thread object used for dispatching background services
  def dispatch_services!
    freshen_dispatches!
    mark_queued_if_empty!
    
    dispatch_foreground!

    # return main thread for background services.
    return dispatch_background!
  end

  # Will run such services in foreground priority waves. And then reload
  # the UmlautRequest object in the current thread, to pick up any
  # changes made in service threads.
  def dispatch_foreground!
    # Foreground services
    (0..9).each do | priority |
      services_to_run = self.instantiate_services!(:level => priority, :ids => runnable_services_for_priority(priority))
      next if services_to_run.empty?
      ServiceWave.new(services_to_run , priority).handle(umlaut_request, umlaut_request.session_id)
    end

    # Need to reload the request from db, so it gets changes
    # made by services in threads, so future code (such as view rendering)
    # will see changes.
    umlaut_request.reload
  end

  # Will run such services in background priority waves. If some
  # services are already running, will not run services in subsequent
  # waves until they are done -- guard against multiple HTTP
  # requests while services in progress. 
  #
  # Returns the Thread object used for dispatching background services. 
  def dispatch_background!
    # Now we do some crazy magic, start a Thread to run our background
    # services. We are NOT going to wait for this thread to join,
    # we're going to let it keep doing it's thing in the background after
    # we return a response to the browser
    backgroundThread = Thread.new(self, umlaut_request) do | t_collection,  t_request|

      # Tell our AR extension not to allow implicit checkouts
      ActiveRecord::Base.forbid_implicit_checkout_for_thread! if ActiveRecord::Base.respond_to?("forbid_implicit_checkout_for_thread!")

      begin
        # Set priority to lower for background thread; may or may not
        # actually have an effect in MRI, unclear, but can't hurt.
        prior = Thread.current.priority
        Thread.current.priority = prior - 1

        # Try to give the thread scheduler another hint, really, get
        # other stuff done before this thread.
        Thread.pass

        force_refresh = false

        ('a'..'z').each do | priority |
          # force refresh only if we just ran some services, otherwise not enough
          # time has gone by to be worthwhile. 
          runnable_ids = runnable_services_for_priority(priority, :refresh => force_refresh)

          services_to_run = self.instantiate_services!(:level => priority, :ids => runnable_ids)
          
          if services_to_run.empty?
            force_refresh = false
            next
          end

          ServiceWave.new(services_to_run , priority).handle(umlaut_request, umlaut_request.session_id)
          force_refresh = true
        end
      rescue Exception => e
        # We are divorced from any HTTP request at this point, and may not
        # have access to an ActiveRecord connection. Not much
        # we can do except log it.
        # If we're catching an exception here, service processing was
        # probably interrupted, which is bad. You should not intentionally
        # raise exceptions to be caught here.
        #
        # Normally even unexpected exceptions were caught inside the ServiceWave,
        # and logged to db as well as logfile if possible, only bugs in ServiceWave
        # itself should wind up caught here.
        Thread.current[:exception] = e
        logger.error("Background Service execution exception: #{e.inspect}\n   " + Umlaut::Util.clean_backtrace(e).join("\n   "))

        # One exception is in test environment, when we may be intentionally
        # trying to get exceptions to propagate up from ServiceWave to here,
        # and then onward, in order to be caught by tests. 
        if self.forward_background_exceptions
          raise e
        end
      end
    end
  end

  # Goes through existing DispatchedService objects, and freshens them up:
  # * If a service is marked in progress longer than timeout, mark
  #   it failed temporary.
  # * If an existing failed temporary is older than our resurrection time,
  #   delete the dispatch (and all it's responses), so it can be re-queued. 
  def freshen_dispatches!
    umlaut_request.dispatched_services.each do | ds |
      # go through dispatched_services and set still in progress but too long to failed temporary
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
             (Time.now - ds.updated_at) > self.requeue_failedtemporary_services_in
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

        umlaut_request.dispatched_services.destroy(ds)            
      end
    end
  end

  # For all configured services, if they have NO DispatchedService
  # object, then create one with status Queued
  def mark_queued_if_empty!
    our_service_ids = self.get_service_definitions.collect {|d| d["service_id"]}

    existing_dispatches = umlaut_request.dispatched_services.collect {|d| d.service_id}

    not_yet_existing = our_service_ids - existing_dispatches

    not_yet_existing.each do |service_id|
      umlaut_request.new_dispatch_object!(service_id, DispatchedService::Queued).save!
    end    
  end

  # All services for priority that are marked Queued, so long as
  # no previous waves are still marked running. 
  #
  # Pass `:refresh => true` as second argument to force trip
  # to the database to get fresh DispatchedService objects. 
  #
  # Returns array of service_id's, or empty array. 
  def runnable_services_for_priority(priority, options = {})
    DispatchedService.connection_pool.with_connection do
      service_definitions = self.get_service_definitions

      # Make a hash where key is service id, and value is priority.to_s
      service_to_priority = Hash[
        service_definitions.collect do |d|
          [ d["service_id"], d["priority"].to_s ]
        end
      ]

      if options[:refresh]
        # force a refresh
        umlaut_request.dispatched_services(true)
      end

      # If there is any service earlier than this wave still marked InProgress, 
      # we're not ready to run this wave, return empty array. 
      # Important to avoid race condition on HTTP requests, don't
      # dispatch later background waves unless earlier are actually complete,
      # even on an HTTP status check. 
      previous_waves_running = umlaut_request.dispatched_services.find do |ds|
        ds.status == DispatchedService::InProgress &&
        service_to_priority[ ds.service_id ] < priority.to_s
      end.present?
      return [] if previous_waves_running

      # otherwise, the services for this priority are runnable if
      # they are already marked Queued
      # We use .to_a, we want to use the already in memory array, not
      # go to the db here. 
      return umlaut_request.dispatched_services.to_a.find_all do |ds|
        ds.status == DispatchedService::Queued &&
        service_to_priority[ ds.service_id ] == priority.to_s
      end.collect {|ds| ds.service_id}
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
      next if svc_def.nil?

      svc_def['service_id'] = unique_id
      task = svc_def['task'] || Service::StandardTask
      level = svc_def['priority'] || 3

      @service_definitions[task] ||= {}
      @service_definitions[task][level] ||= []
      @service_definitions[task][level] << svc_def
    end
  end





end
