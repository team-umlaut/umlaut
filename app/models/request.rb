class Request < ActiveRecord::Base  

  has_many :dispatched_services
  # Order service_type joins (ie, service_responses) by id, so the first
  # added to the db comes first. Less confusing to have a consistent order.
  # Also lets installation be sure services run first will have their
  # responses show up first. 
  has_many :service_types, :order=>'service_types.id ASC'
  belongs_to :referent
  belongs_to :referrer

  def self.new_request(params, session, a_rails_request )
    
    # Sometimes umlaut puts in a 'umlaut.request_id' parameter.
    # first look by that, if we have it, for an existing request.  
    begin            
      request_id = params['umlaut.request_id']
      # Be sure to use session id too to guard against spoofing by guessing
      # request ids from another session.
      req = Request.find(:first, :conditions => ["session_id = ? and id = ?", session.session_id, request_id] ) unless request_id.nil? || @user_request      
    rescue  ActiveRecord::RecordNotFound
      # Bad request id? Okay, pretend we never had a request_id at all. 
      request_id = nil
      req = nil
    end
    
    unless (req)
      # If not found yet, then look for an existing request that had the same
      # params as this one, in the same session. In which case, reload.
      # Except we don't preserve certain Rails and app controller params--
      # only the ones that are actually the OpenURL, is the idea.
  
      # We don't want to use the entire params. It includes things
      # that are NOT part of the ContextObject, but are just part of
      # rails or the app. Strip em out.
      co_params = self.extract_co_params( params )
      serialized_params = self.serialized_co_params( co_params )
      
      req = Request.find(:first, :conditions => ["session_id = ? and params = ?", session.session_id, serialized_params ])

      unless (req)
        # Nope, okay, we don't have a complete Request, but let's try finding
        # an already existing referent and/or referrer to use, if possible, or
        # else create new ones. 
    
        # Find or create a Referent
        context_object = OpenURL::ContextObject.new
        context_object.import_hash( co_params )
        
        rft = Referent.find_or_create_by_context_object(context_object)
    
        # Find or create a referrer, if we have a referrer in our OpenURL
        rfr = nil
        rfr = Referrer.find_or_create_by_identifier(context_object.referrer.identifier) unless context_object.referrer.empty?
    
        # Create the Request
        req = Request.new
        req.session_id = session.session_id
        req.params = serialized_params
        rft.requests << req
        (rfr.requests << req) if rfr

        # Save client ip
        req.client_ip_addr = params['req.ip'] || a_rails_request.remote_ip()
        req.client_ip_is_simulated = true if req.client_ip_addr != a_rails_request.remote_ip()
        
        req.save!
      end
    end

    return req
  end

  # Status can be true, false, or one of the DispatchedService status codes.
  # If row already exists in the db, that row will be re-used, over-written
  # with new status value.
  def dispatched(service, status, exception=nil)
    
    ds = self.find_dispatch_object( service )
    unless ds
      ds= self.new_dispatch_object!(service, status)
    end
    # In case it was already in the db, make sure to over-write status.
    # and add the exception either way.     
    ds.status = status
    ds.store_exception( exception )
    
    ds.save!
  end


  # See can_dispatch below, you probably want that instead.
  # This method checks to see if a particular service has been dispatched, and
  # is succesful or in progress---that is, if this method returns false,
  # you might want to dispatch the service (again). If it returns true though,
  # don't, it's been done. 
  def dispatched?(service)
    ds= self.dispatched_services.find(:first, :conditions=>{:service_id => service.id})
    # Return true if it exists and is any value but FailedTemporary.
    # FailedTemporary, it's worth running again, the others we shouldn't. 
    return (! ds.nil?) && (ds.status != DispatchedService::FailedTemporary)
  end
  # Someone asks us if it's okay to dispatch this guy. Only if it's
  # marked as Queued, or Failed---otherwise it should be already working,
  # or done. 
  def can_dispatch?(service)
    ds= self.dispatched_services.find(:first, :conditions=>{:service_id => service.id})
    
    return ds.nil? || (ds.status == DispatchedService::Queued) || (ds.status == DispatchedService::FailedTemporary)        
  end

  # Will set dispatch record to queued for service--but only if it
  # wasn't already set to somethign else! Existing status will not
  # be-overwritten. Used preliminarily to dispatching background
  # services. 
  def dispatched_queued(service)
    ds = find_dispatch_object(service)
    unless ( ds )
      ds = new_dispatch_object!(service, DispatchedService::Queued)
    end
    return ds
  end
  

  # second arg is an array of ServiceTypeValue objects, or
  # an array of 'names' of ServiceTypeValue objects. Ie,
  # ServiceTypeValue[:fulltext], or "fulltext" both work. 
  def add_service_response(response_data,service_type=[])
    unless response_data.empty?
      #svc_resp = nil
      
      #ServiceResponse.find(:all, :conditions=>{:service_id => #response_data[:service].id, :response_key => response_data[:key], #:value_string => response_data[:value_string],:value_alt_string => response_data[:value_alt_string]}).each do | resp |
      #  svc_resp = resp if YAML.load(resp.value_text.to_s) == YAML.load(response_data[:value_text].to_s)
      #end
      #unless svc_resp
        svc_resp = ServiceResponse.new

        
        svc_resp.url = response_data[:url]
        svc_resp.notes = response_data[:notes]
        svc_resp.display_text = response_data[:display_text]
        svc_resp.init_service_data(response_data[:service_data])
        
        svc_resp.service_id = response_data[:service].id
        svc_resp.response_key = response_data[:key]
        svc_resp.value_string = response_data[:value_string]
        svc_resp.value_alt_string = response_data[:value_alt_string]
        svc_resp.value_text = response_data[:value_text]           
        svc_resp.save!
        
      #end
    end
    unless service_type.empty?
      service_type.each do | st |
        #stype = ServiceType.find(:first, :conditions=>{:request_id => self.id, :service_response_id => svc_resp.id,:service_type => st})
        
        #unless stype
          stype = ServiceType.new(:request => self, :service_response => svc_resp, :service_type_value => st)
          stype.save!
        #end
      end
    end
  end

  # original context object params. 
  # We serialize our params in weird ways. (See below). Use this to turn em
  # back into a params hash. Returns hash. 
  def original_co_params(arguments = {})        
    new_hash = {}
    list = YAML.load( self.params )
    list.each do | mini_hash |
      
      new_hash.merge!(mini_hash) 
    end
    # If requested we put in the request_id, even though it's not really
    # a context object element.
    new_hash['umlaut.request_id'] = self.id if arguments[:add_request_id]
    
    return new_hash
  end

  # Methods to look at status of dispatched services
  def failed_service_dispatches
    return self.dispatched_services.find(:all, 
      :conditions => ['status IN (?, ?)', 
      DispatchedService::FailedTemporary, DispatchedService::FailedFatal])
  end

  # Returns array of Services in progress or queued. Intentionally
  # uses cached in memory association, so it wont' be a trip to the
  # db every time you call this. 
  def services_in_progress
    
    # Intentionally using the in-memory array instead of going to db.
    # that's what the "to_a" is. Minimize race-condition on progress
    # check, to some extent, although it doesn't really get rid of it. 
    dispatches = self.dispatched_services.to_a.find_all do | ds |
      (ds.status == DispatchedService::Queued) || 
      (ds.status == DispatchedService::InProgress)
    end

    svcs = dispatches.collect { |ds| ds.service }
    return svcs
  end
  # convenience method to call service_types_in_progress with one element. 
  def service_type_in_progress?(svc_type)
    return service_types_in_progress?( [svc_type] )
  end
  
  #pass in array of ServiceTypeValue or string name of same. Returns
  # true if ANY of them are in progress. 
  def service_types_in_progress?(type_array)
    # convert strings to ServiceTypeValues
    type_array = type_array.collect {|s|  s.kind_of?(ServiceTypeValue)? s : ServiceTypeValue[s] }
    
    self.services_in_progress.each do |s|
      # array intersection
      return true unless (s.service_types_generated & type_array).empty? 
    end
    return false;
  end
  
  def any_services_in_progress?
    return services_in_progress.length > 0
  end

  def to_context_object
    #Mostly just the referent
    context_object = self.referent.to_context_object

    #But a few more things
    context_object.referrer.add_identifier(self.referrer.identifier) if self.referrer

    context_object.requestor.set_metadata('ip', self.client_ip_addr) if self.client_ip_addr

    return context_object
  end

  # Is the citation represetned by this request a title-level only
  # citation, with no more specific article info? Or no, does it
  # include article or vol/iss info?
  def title_level_citation?
    data = referent.metadata

    # atitle can't generlaly get us article-level, but it can with
    # lexis nexis, so we'll consider it article-level. Since it is!
    return ( data['atitle'].blank? &&
             data['volume'].blank? &&
             data['issue'].blank? &&
             data['spage'].blank? &&
             data['date'].blank? &&
        # pmid or doi is considered article-level, because SFX can
        # respond to those. Other identifiers may be useless. 
        (! referent.identifiers.find {|i| i =~ /^info\:(doi|pmid)/})
        )
  end

  # pass in string name of a service type value, get back list of
  # ServiceType objects with that value belonging to this request. 
  # This one does make a db transaction, to get most up to date list. 
  def get_service_type(svc_type)
    return self.service_types.find(:all,
                              :conditions =>
                                 ["service_type_value_id = ?",
                                 ServiceTypeValue[svc_type].id ],
                              :include => [:service_response]   
                              )
  end
  
  protected

  def find_dispatch_object(service)
    return self.dispatched_services.find(:first, :conditions=>{:service_id => service.id})
  end
  # Warning, doesn't check for existing object first. Use carefully, usually
  # paired with find_dispatch_object. Doesn't actually call save though,
  # caller must do that (in case caller wants to further initialize first). 
  def new_dispatch_object!(service, status)
    ds = DispatchedService.new
    ds.service_id = service.id
    ds.status = status
    self.dispatched_services << ds
    return ds
  end

  # Extract context object params. Strips out params from incoming
  # request that are not part of the context object, but instead
  # part of Rails framework or app-specific controller params. 
  def self.extract_co_params( params )
  
    # Strings or regexps
    # Oops, we can't exclude 'id' even though we often use it for something
    # other than a context object, because it's also used for a legitimate
    # OpenURL 0.1 context object. Oops. Hmm. Maybe we're better NOT
    # to use 'id' in the Rails way. Hmm. 
    excluded_keys = ["action", "controller", "page", /^umlaut\./, 'rft.action', 'rft.controller']

    new_params = params.clone
    new_params.keys.each do |key|              
      excluded_keys.each do |exclude|
        if exclude === key ; new_params.delete(key) ; end
      end          
    end
    # 'id' is a special one, cause it can be a OpenURL 0.1 key, or
    # it can be just an application-level primary key. If it's only a
    # number, we assume the latter--an openurl identifier will never be
    # just a number. 
    if new_params['id'] =~ /^\d+$/
      new_params.delete('id')
    end

    return new_params
  end
  
  # Serialized context object params. 
  # We save our incoming params to disk, so later we can compare to see
  # if we have the same request. Two problems: 1) Just serializing a hash is
  # no good for later string comparison in the db, because hash key order
  # can be different. 2) Our hash includes some Rails (and umlaut) only
  # stuff that isn't really part of the context object, and we don't want
  # to include.
  # This method takes care of #1---pass in params that have already
  # been cleaned with extract_co_params for #2. 
  def self.serialized_co_params(params)
    excluded_keys = ["action", "controller", "page", /^umlaut\./,  "rft.action", "rft.controller"]

    # 'id' is a weird one because it IS an OpenURL 0.1 param, but the
    # same key is often used for an internal Rails/Umlaut arg. So we
    # save it, sometimes saving 'bad' keys. We really ought not to use
    # it as a URL param in Umlaut. 
        
    # Okay, we're going to turn it into a list of one-element hashes,
    # alphabetized by key. To attempt to make it so the same hash
    # always turns into the exact same yaml string. Hopefully it'll work.
    list = []
    params.keys.sort.each do |key|
      #debugger
      excluded = false
      excluded_keys.each {|exclude_key| excluded = true if exclude_key === key }
          
      list.push( {key => params[key]} ) unless excluded
    end
    serialized = list.to_yaml
    # If serialized is bigger than the column width available, we're in trouble.
    if serialized.length > self.columns_hash['params'].limit
      # We should do something other than raise, but I don't know what.   
      raise "Serialized context object params will be truncated! Maximum size #{self.columns_hash['params'].limit}, actual size #{serialized.length}"
    end
    return serialized
  end

end
