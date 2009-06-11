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
  # and services.
  def initialize(umlaut_request, session)
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

    RAILS_DEFAULT_LOGGER.debug("Collection initialize time: #{Time.now - start_t}")
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
  
    # Add default institutions
    InstitutionList.instance.default_institutions.each do | dflt |
      @institutions << dflt
    end
    
    # Get any institutions that the user has associated with themself
    get_user_institutions

    # Check if they are eligible for other services/institutions
    # based on their physical location. Commented out till we fix it. 
    #get_institutions_for_ip(@client_ip, @rails_session)      

    # We've added institutions, now add all the services belonging to those institutions.
    gather_services()
  end

  # Add services belonging to institutions
  def gather_services
    @institutions.each do | inst |
      next if inst.services.nil?  
    
      inst.services.each do | svc_id |
        svc_def = ServiceList.instance.definition(svc_id)
            
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

  # Experimental, not in use. 
  # Queries the OCLC Resolver Registry for any services
  # associated with user's IP Address.
  # Not currently working. Do not use until fixed and tested.
  # Not even sure what this is supposed to do, since an Institution
  # doesn't neccesarily exist for the registry entry. Create one? Needs
  # to be rethunk. 
  def get_institutions_for_ip(ip, session)
    require 'resolver_registry'

    client = ResolverRegistry::Client.new
    client.lookup_all(ip).each do | inst |
      # If we already have an institution matching this guy, skip it. 
      next if worldcat_institution_in_collection?(inst, :check_resolver_url => true)
          
      # If we can possibly have an SFX resolver, check for it.
      if ( (! inst.resolver.base_url.nil?) &&
           (inst.resolver.vendor.nil? ||
            inst.resolver.vendor.downcase == 'sfx' ||
            inst.resolver.vendor.downcase == 'other') &&
           check_supported_resolver(inst.resolver.base_url))

           # We checked for it, it's good
           sfx = Sfx.new({"service_id"=>"#{inst.oclc_inst_symbol}_#{inst.institution_id}_SFX", "priority"=>2, "display_name"=>inst.name, "base_url"=>inst.resolver.base_url})
           service_level(2) << sfx unless service_level(2).index(sfx)
           
      elsif (! inst.resolver.base_url.nil?)
        # Okay, no SFX, but we can still do coins! 
        enable_session_coins(inst.resolver.base_url, inst.resolver.link_icon, inst.name, session)
      end
    end 		
  end

  # Experimental, not in use. 
  # Checks to see if a worldcat registry institution
  # duplicates institutions already in our collection.
  # Checks worldcat registry ID, OCLC symbol, and, if
  # :check_resolver_url => true, resolver URL itself. 
  def worldcat_institution_in_collection?(worldcat_inst, params={})      
    matched = false


    @institutions.each do | coll_inst |
      break if matched # no need to keep looking if we've matched
      
      matched = matched || 
        (coll_inst.oclc_symbol ==  worldcat_inst.oclc_inst_symbol )      
      matched = matched || 
        (coll_inst.worldcat_registry_id == worldcat_inst.institution_id )
        
      if params[:check_resolver_url]
        coll_inst.services.each do | svc |
          break if matched # don't need to keep looking if we've found          
          next unless svc.respond_to?(:base_url)          
          matched = matched || 
            (svc.base_url == worldcat_inst.resolver.base_url )      
        end          
      end
      
    end

    return matched
  end
  
  # Experimental, not in use.
  # This method is supposed to test a suspected foreign SFX instance
  # to see if we can succesfully connect to the API. 
  def check_supported_resolver(resolver)


    require 'service_adaptors/sfx'
    ctx = OpenURL::ContextObject.new
    ctx.import_kev 'ctx_enc=info%3Aofi%2Fenc%3AUTF-8&ctx_id=10_1&ctx_tim=2006-8-4T14%3A11%3A44EDT&ctx_ver=Z39.88-2004&res_id=http%3A%2F%2Forion.galib.uga.edu%2Fsfx_git1&rft.atitle=Opening+up+OpenURLs+with+Autodiscovery&rft.aufirst=Daniel&rft.aulast=Chudnov&rft.date=2005-04-30&rft.genre=article&rft.issn=1361-3200&rft.issue=43&rft.jtitle=Ariadne&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Ajournal&svc_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Asch_svc&url_ctx_fmt=info%3Aofi%3Afmt%3Akev%3Amtx%3Actx&url_ver=Z39.88-2004'
    sfx = Sfx.new({"base_url"=>resolver})
    transport = OpenURL::Transport.new(resolver)
    transport.add_context_object(ctx)
    transport.extra_args["sfx.response_type"]="multi_obj_xml"    
    response = sfx.do_request(transport)
    begin
      doc = REXML::Document.new response
    rescue REXML::ParseException
      return false
    end
    return false unless doc.elements['ctx_obj_set']
      
    return true
  end    

  # Experimental, not in use. 
  def enable_session_coins(host, icon, text, session)
    unless session[:coins]
      session[:coins] = []
    end
    session[:coins] << {:host=>host, :icon=>icon, :text=>text}    
  end  
  


end
