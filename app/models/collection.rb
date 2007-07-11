# A collection is a hash that contains all of the resources
# that should be a available to a given user. institutions
# attribute stores all the institutions belonging to user,
# from which services can be found. 
class Collection
  
  attr_accessor :institutions
  require 'open_url'
  
  # Build a new Collection object and gather appropriate institutions
  # and services.
  def initialize(ip, session)
    @institutions= []
    @services = {} 
    (0..9).each do | priority |
      @services[priority] = []
    end
    @services['background'] = []
    if session[:refresh_collection] == true
      session[:collection] = nil
      session[:refresh_collection] = false
    end      
    self.gather_institutions(ip, session)
    self.gather_services
  end
  
  def gather_institutions(ip, session)
    
    # If we've gone through this process already, an abridged
    # version should be in the user's session.  If the user's
    # Collection needs to be rebuilt, set the ':refresh_collection'
    # key to true
    unless session[:collection] 
      Institution.find_all_by_default_institution(true).each do | dflt |
        @institutions << dflt
      end
      # Users always get the home institutions
      #@institutions << default_institution
      # Just set the collection id to the session
      session[:collection] = {:institutions=>[], :services => {}}
      (0..9).each do | priority |
        session[:collection][:services][priority] = []
      end
      @institutions.each do | inst |
        session[:collection][:institutions] << inst.id
      end
      
      # Get any institutions that the user has associated with themself
      self.get_user_institutions(session)
      
      # Check if they are eligible for other services
      # based on their physical location
      self.get_institutions_for_ip(ip, session)
    else 
      # Build collection object from session
      session[:collection][:institutions].each do  | inst |
        begin
          @institutions << Institution.find(inst)
        rescue ActiveRecord::RecordNotFound
          # Institution in session isn't in db anymore? Okay, just ignore it. 
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
           sfx = Sfx.new({"id"=>"#{inst.oclc_inst_symbol}_SFX", "priority"=>2, "display_name"=>inst.name, "base_url"=>inst.resolver.base_url})
           @services[2] << sfx unless @services[2].index(sfx)
           session[:collection][:services][2] << sfx.to_yaml
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
      
      matched = matched || 
        (coll_inst.oclc_symbol ==  worldcat_inst.oclc_inst_symbol )      
      matched = matched || 
        (coll_inst.worldcat_registry_id == worldcat_inst.institution_id )

      break if matched # no need to keep looking if we've matched
        
      if params[:check_resolver_url]
        coll_inst.services.each do | svc |
          next unless svc.responds_to?(:base_url)          
          matched = matched || 
            (svc.base_url == worldcat_inst.resolver.base_url )
          break if matched # don't need to keep looking if we've found
        end          
      end
      
    end

    return matched
  end
  
  # Checks a service pointing to the resolver is
  # already in the collection object
  #def in_collection?(resolver_host)
  #  @institutions.each do | inst |
  #    inst.services.each do | svc |
  #      return true if svc.url == resolver_host
  #    end
  #  end
  #  return false
  #end
  
  def check_supported_resolver(resolver)
    # This method is supposed to test a suspected foreign SFX instance
    # to see if we can succesfully connect to the API. However, it doesn't
    # currently work, so I've temporarily disabled it, all foreign
    # SFX instances will be assumed NOT available.

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
  
  #def check_oclc_symbol(nuc)
  #  @institutions.each do | inst |
  #    return true if inst.oclc_symbol == nuc
  #  end
  #  return false  
  #end
  
  def gather_services
    # Global institution should be marked as a default, we don't need
    # special treatment for it. 
    #InstitutionList.get('global')["services"].each do | svc |   
    #  s = ServiceList.get(svc)
    #  @services[s.priority] << s
    #end
    @institutions.each do | inst |
      next if inst.services.nil?  
    
      inst.services.each do | svc |
        @services[svc.priority] << svc
      end
    end
  end

  # Returns all services at the given level. 0-9 for foreground,
  # a-z for background. 
  def service_level(level)
    return @services[level]
  end
end
