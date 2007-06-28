class Collection
  # A collection is a hash that contains all of the resources
  # that should be a available to a given user.
  # The 'collections' attribute is a hash containing an array 
  # of institutions (and its services) that are available to a user
  # and a hash of 'extra' services based on the users ip, for example.
  # Collection.new takes the user's ip address and their session hash 
  # and either finds the collections from the user or recreates it from
  # their session.
  
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
      # Users always get the home institution
      #@institutions << default_institution
      # Just set the collection id to the session
      session[:collection] = {:institutions=>[], :services => {}}
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
        @institutions << Institution.find(inst)
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
      next if self.in_collection?(inst.resolver.base_url)
      next if self.check_oclc_symbol(inst.oclc_inst_symbol)
      if inst.resolver.vendor == 'sfx' or vendor.get_text.value.downcase == 'other'
        if check_supported_browser(inst.resolver.base_url)
          sfx = Sfx.new({:name=>inst.name, :url=>inst.resolver.base_url})
          @services << sfx unless @services.index(sfx)
          session[:collection][:services] << sfx.to_yaml
        end         
      else
        self.enable_session_coins(inst.resolver.base_url, inst.resolver.link_icon, inst.name, session)
      end
    end 		
  end
  
  # Checks if the resolver is already in the collection object
  def in_collection?(resolver_host)
    @institutions.each do | inst |
      inst.services.each do | svc |
        return true if svc.url == resolver_host
      end
    end
    return false
  end
  
  def check_supported_resolver(resolver)
    require 'sfx_client'
    ctx = OpenURL::ContextObject.new
    ctx.import_kev 'ctx_enc=info%3Aofi%2Fenc%3AUTF-8&ctx_id=10_1&ctx_tim=2006-8-4T14%3A11%3A44EDT&ctx_ver=Z39.88-2004&res_id=http%3A%2F%2Forion.galib.uga.edu%2Fsfx_git1&rft.atitle=Opening+up+OpenURLs+with+Autodiscovery&rft.aufirst=Daniel&rft.aulast=Chudnov&rft.date=2005-04-30&rft.genre=article&rft.issn=1361-3200&rft.issue=43&rft.jtitle=Ariadne&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Ajournal&svc_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Asch_svc&url_ctx_fmt=info%3Aofi%3Afmt%3Akev%3Amtx%3Actx&url_ver=Z39.88-2004'
    sfx = SfxClient.new(ctx, resolver)
    response = sfx.do_request
    begin
      doc = REXML::Document.new response
    rescue REXML::ParseException
      return false
    end
    unless set = doc.elements['ctx_obj_set']
      return false
    end
    return true
  end    
  
  def enable_session_coins(host, icon, text, session)
    unless session[:coins]
      session[:coins] = []
    end
    session[:coins] << {:host=>host, :icon=>icon, :text=>text}    
  end  
  
  def check_oclc_symbol(nuc)
    @institutions.each do | inst |
      return true if inst.oclc_symbol == nuc
    end
    return false  
  end
  
  def gather_services
    InstitutionList.get('global')["services"].each do | svc |   
      s = ServiceList.get(svc)
      @services[s.priority] << s
    end
    @institutions.each do | inst |
      inst.services.each do | svc |
        @services[svc.priority] << svc
      end
    end
  end
  
  def service_level(level)
    return @services[level]
  end
end
