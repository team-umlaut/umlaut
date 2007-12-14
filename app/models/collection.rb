# Collection object calculates and manages Institutions and Services
# belonging to a particular user/request. It stores it's data in
# session in a weird way. 
class Collection
  
  attr_accessor :institutions
  
  # Build a new Collection object and gather appropriate institutions
  # and services.
  def initialize(ip, session)
    @institutions= []
    @services = {}
    @link_out_filters = {}
    # fill out 0..9

    # If IP address has changed, then refresh the collection
    # (IP can change in a session if you take your laptop to a different
    #  wireless net; if you turn on VPN; if you've specified a new
    #  ip in the req.ip context object; various other reasons. )
    if ( session[:collection] && 
         session[:collection][:client_ip_addr] != ip)
         session[:refresh_collection] = true
    end

    
    if session[:refresh_collection] == true
      session[:collection] = nil
      session[:refresh_collection] = false
    end

    
    # Data has been created and stored in session already, load it from
    # there. Code can set session[:refresh_collection] = true to force
    # re-calc on next Collection creation.
    if (session[:collection] && session[:collection][:services] && session[:collection][:institutions])
      self.load_from_session(session)
      # We still currently need to re-calculate services every time
      # anyway
      #self.gather_services
    else
      # No data stored in session, so calculate it, and save it.
      self.calculate_collection_data(ip, session)
      self.save_to_session(ip, session)
    end
    
  end



  # Right now we only save institutions, not services. Hmm. 
  def save_to_session(ip, session)
    
    # Create and blank out our data structure
    session[:collection] = {:institutions=>[], 
                            :services => {},
                            :service_class_names => [],
                            :client_ip_addr => nil }

   # Save client ip, so we can make sure to uncache if it changes
   session[:collection][:client_ip_addr] = ip

    # Save institution IDs. We'll refetch em from db later. 
    @institutions.each do | inst |
      session[:collection][:institutions] << inst.id
    end

    # Save our whole array of services to session, where they'll be
    # automagically serialized. Services aren't kept in db right now,
    # so can't just store ids. But we're going to take care of serialization
    # instead of letting framework do it, to let us figure out how to
    # deal with 'require' easier. 
    # Have to save names of all Service classes used, so we can make
    # sure to load them on the way out.
    class_names = @services.values.flatten.collect {|s| s.class.name }
    class_names.concat( @link_out_filters.values.flatten.collect {|s| s.class.name } )
    class_names.uniq!    
    session[:collection][:service_class_names] = class_names 
    
    session[:collection][:services] = @services.to_yaml
    session[:collection][:link_out_filters] = @link_out_filters.to_yaml
  end

  # Right now we only store institutions in session. We rebuild services
  # on every request. Need to fix that. 
  def load_from_session(session)    
    @institutions = []

    data = session[:collection]
    return unless data

    # Load institutions from IDs. If the ID no longer exists in the db,
    # we'll just silently ignore it, which is fine. 
    inst_ids = data[:institutions]
    @institutions = Institution.find(:all, :conditions => ['id in (?)', inst_ids.join(',') ])

    # Services were manually marshalled whole in session as yaml.
    # First we need to make sure and 'require' all the service classes.
    if (data[:service_class_names] && data[:services])
      data[:service_class_names].each do |class_name|
        ServiceList.require_service_class( class_name )
      end
      # And now we can actually load them all. 
      @services = YAML.load(data[:services])
      @link_out_filters = YAML.load( data[:link_out_filters])
    end
  end
  
  def calculate_collection_data(ip, session)
  
    # Add default institutions
    Institution.find_all_by_default_institution(true).each do | dflt |
      @institutions << dflt
    end
    
    # Get any institutions that the user has associated with themself
    self.get_user_institutions(session)

    # Check if they are eligible for other services/institutions
    # based on their physical location. Commented out till we fix it. 
    #self.get_institutions_for_ip(ip, session)      

    # We've added institutions, now add all the services belonging to those institutions.
    self.gather_services()
  end

  # Add services belonging to institutions
  def gather_services
    @institutions.each do | inst |
      next if inst.services.nil?  
    
      inst.services.each do | svc |
        task = svc.task || Service::StandardTask
        
        case task
        when Service::LinkOutFilterTask
          link_out_service_level(svc.priority) << svc
        else # standard
          service_level(svc.priority) << svc
        end
      end      
    end

        
    
  end
  
  def get_user_institutions(session)
    #can only do it if we have a user
    return unless session[:user]  
    
    user = User.find_by_id(session[:user][:id])
    user.institutions.each do | uinst |
      @institutions << uinst unless @institutions.index(uinst) 
    end
  end
  
  # Queries the OCLC Resolver Registry for any services
  # associated with user's IP Address.
  def get_institutions_for_ip(ip, session)
    require 'resolver_registry'

    client = ResolverRegistry::Client.new
    client.lookup_all(ip).each do | inst |
      # If we already have an institution matching this guy, skip it. 
      next if self.worldcat_institution_in_collection?(inst, :check_resolver_url => true)
          
      # If we can possibly have an SFX resolver, check for it.
      if ( (! inst.resolver.base_url.nil?) &&
           (inst.resolver.vendor.nil? ||
            inst.resolver.vendor.downcase == 'sfx' ||
            inst.resolver.vendor.downcase == 'other') &&
           check_supported_resolver(inst.resolver.base_url))

           # We checked for it, it's good
           sfx = Sfx.new({"id"=>"#{inst.oclc_inst_symbol}_#{inst.institution_id}_SFX", "priority"=>2, "display_name"=>inst.name, "base_url"=>inst.resolver.base_url})
           service_level(2) << sfx unless service_level(2).index(sfx)
           
      elsif (! inst.resolver.base_url.nil?)
        # Okay, no SFX, but we can still do coins! 
        self.enable_session_coins(inst.resolver.base_url, inst.resolver.link_icon, inst.name, session)
      end
    end 		
  end

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
  
  
  def check_supported_resolver(resolver)
    # This method is supposed to test a suspected foreign SFX instance
    # to see if we can succesfully connect to the API. 

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
  
  def enable_session_coins(host, icon, text, session)
    unless session[:coins]
      session[:coins] = []
    end
    session[:coins] << {:host=>host, :icon=>icon, :text=>text}    
  end  
  


  # Returns all services at the given level. 0-9 for foreground,
  # a-z for background. 
  def service_level(level)    
    # lazy init to empty array if neccesary
    return (@services[level] ||= [])
  end

  def link_out_service_level(level)
    return (@link_out_filters[level] ||= [])
  end
end
