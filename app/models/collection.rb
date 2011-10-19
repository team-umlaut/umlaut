# Collection object calculates and manages Institutions and Services
# belonging to a particular user/request. It is initialized with the
# the umlaut Request object (from which client IP can be obtained),
# and the rails session hash. It doesn't currently do much with either
# of those things, although in the future it may cache some things in session,
# may look for a logged in user in session, may use client IP to determine
# services/institutions. 
#
class Collection
  
  attr_accessor :institutions
  
  # Build a new Collection object and gather appropriate institutions
  # and services. Pass in a specified institution name
  # in third parameter to use only that institution, otherwise we'll
  # use default institutes. 
  def initialize(umlaut_request, session, aInstitution = nil)
    @requested_institution = aInstitution
    @client_ip = umlaut_request.client_ip_addr
    @umlaut_request = umlaut_request
    @rails_session = session
    @institutions= []
    # @service_definitions will be a two-level hash, pointing to an array.. Task is Standard, LinkOut, etc.
    # { [task] => { [priority_level] => [config1, config2, config3],
    #                [priority_level_2] => [configa], }
    #     [...]
    # }
    @service_definitions = {}
    @link_out_filters = {}
    
    start_t = Time.now

    # Calculate our collection data
    calculate_collection_data

    Rails.logger.debug("Collection initialize time: #{Time.now - start_t}")
  end


  # Instantiate new copies of services included in this collection, which
  # services specified by options. 
  # :task => Service::StandardTask (default) or Service::LinkOutFilterTask
  # :level => priority level, default to returning services from all. 
  def instantiate_services!(options ={})
    get_service_definitions(options).collect {|svc_def| ServiceList.instance.instantiate!(svc_def["service_id"], @umlaut_request)}
  end

  # Return a new copy of service with id specified, initialized with current
  # umlaut request. 
  def instantiate_service!(id)
    ServiceList.instance.instantiate!(id, @umlaut_request)    
  end

  # Deprecated, use instantiate_services! instead. 
  # Returns all services at the given level. 0-9 for foreground,
  # a-z for background. Deprecated, use #instantiate_services! setting
  # :level => level. 
  def service_level(level)    
    instantiate_services!(:level => level)
  end

  # Deprecated, use instantiate_services! instead.
  # Returns all foreground or background services. 
  def all_regular_services
    instantiate_services!
  end



  # Deprecated, use #instantiate_services! with :task => Service::LinkOutFilter.
  def link_out_service_level(level)
    instantiate_services!(:task => Service::LinkOutFilterTask, 
                          :level => level)
  end

  protected

  # Get service definition hashes for services in this institution.
  # options, returned in an array. 
  # Does return a mutatable array that Collection mutates
  # internally, but clients really ought not to mutate. 
  # :task => Service::StandardTask (default) or Service::LinkOutFilterTask
  # :level => priority level, default to returning services from all. 
  def get_service_definitions(options = {})
    options[:task] ||= Service::StandardTask
    
    configs_for_task = @service_definitions[ options[:task] ] || {}
    
    service_configs = case options[:level]
                        when nil
                          # All of of them for this task
                          configs_for_task.values.flatten
                        else
                          configs_for_task[ options[:level] ]
                      end

     # Make sure it's an emtpy array, not nil.                           
     return service_configs || []    
  end


  def calculate_collection_data
    @institutions = []
    if @requested_institution      
      i = InstitutionList.instance.get(@requested_institution)
      @institutions << i if i    
    else
      # Add default institutions
      InstitutionList.instance.default_institutions.each do | dflt |
        @institutions << dflt
      end
    end
    
    # Get any institutions that the user has associated with themself
    get_user_institutions   

    # We've added institutions, now add all the services belonging to those institutions.
    gather_services()
  end

  # Add services belonging to institutions
  def gather_services
    @institutions.each do | inst |
      next if inst.services.nil?  
    
      inst.services.each do | svc_id |
        svc_def = ServiceList.instance.definition(svc_id)
        
        if svc_def.nil?
          #raise Exception.new("Service referenced in institution, but not defined in services.yml: #{svc_id}")
          Rails.logger.warn("Service referenced in institution, but not defined in services.yml: #{svc_id}")
          next;
        end        
      
        task = svc_def['task'] || Service::StandardTask
        level = svc_def['priority']
        
        @service_definitions[task] ||= {}
        @service_definitions[task][level] ||= []
        @service_definitions[task][level] << svc_def                              
      end      
    end
  end

  

  
  def get_user_institutions
    session = @rails_session
  
    # not currently implemented
    return nil
    
  
    #can only do it if we have a user
    #return unless session[:user]  
    
    #user = User.find_by_id(session[:user][:id])
    #user.institutions.each do | uinst |
    #  @institutions << uinst unless @institutions.index(uinst) 
    #end
  end
  


end
