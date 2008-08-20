# An ActiveRecord which represents a parsed OpenURL resolve service request,
# and other persistent state related to Umlaut's handling of that OpenURL 
# request) should not be confused with the Rails ActionController::Request 
# class (which represents the complete details of the current 'raw' HTTP
# request, and is not stored persistently in the db).
#
# Constituent openurl data is stored in Referent and Referrer. 
class Request < ActiveRecord::Base

  has_many :dispatched_services
  # Order service_type joins (ie, service_responses) by id, so the first
  # added to the db comes first. Less confusing to have a consistent order.
  # Also lets installation be sure services run first will have their
  # responses show up first. 
  has_many :service_types, :order=>'service_types.id ASC', :include=>:service_response
  belongs_to :referent, :include => :referent_values
  belongs_to :referrer
  # holds a hash representing submitted http params
  serialize :http_env

  # Either creates a new Request, or recovers an already created Request from
  # the db--in either case return a Request matching the OpenURL.
  def self.new_request(params, session, a_rails_request )

    # Pull out the http params that are for the context object,
    # returning a CGI::parse style hash, customized for what
    # ContextObject.new_from_form_vars wants. 
    co_params = self.context_object_params( a_rails_request )
    
    # Create a context object from our http params
    context_object = OpenURL::ContextObject.new_from_form_vars( co_params )
    # Sometimes umlaut puts in a 'umlaut.request_id' parameter.
    # first look by that, if we have it, for an existing request.  
    request_id = params['umlaut.request_id']

    # We're trying to identify an already existing response that matches
    # this request, in this session.  We don't actually match the
    # session_id in the cache lookup though, so background processing
    # will hook up with the right request even if user has no cookies. 
    # But if IP has changed, don't re-use the request, becuase ip change
    # may result in different responses.
    client_ip = params['req.ip'] || a_rails_request.remote_ip()
    req = Request.find(:first, :conditions => ["id = ? and client_ip_addr = ?", request_id, client_ip] ) unless request_id.nil?
    
    # No match?  Just pretend we never had a request_id in url at all.
    request_id = nil if req == nil

    # Serialized fingerprint of openurl http params, suitable for looking
    # up in the db to see if we've seen it before. 
    param_fingerprint = self.co_params_fingerprint( co_params )
    
    unless (req)
      # If not found yet, then look for an existing request that had the same
      # openurl params as this one, in the same session. In which case, reuse.
      # Here we do require same session, since we don't have an explicit
      # request_id given. 

      req = Request.find(:first, :conditions => ["session_id = ? and contextobj_fingerprint = ? and client_ip_addr = ?", session.session_id, param_fingerprint, client_ip ] ) unless param_fingerprint.blank?
    end
    
    # Okay, if we found a req, it might NOT have a referent, it might
    # have been purged. If so, create a new one.
    if ( req && ! req.referent )
      req.referent = Referent.find_or_create_by_context_object(context_object, req.referrer)
    end

    unless (req)
      # didn't find an existing one at all, just create one
      req = self.create_new_request!( :params => params, :session => session, :rails_request => a_rails_request, :contextobj_fingerprint => param_fingerprint, :context_object => context_object )
    end

    return req
  end

  # input is a Rails request (representing http request)
  # We pull out a hash of request params (get and post) that
  # define a context object. We use CGI::parse instead of relying
  # on Rails parsing because rails parsing ignores multiple params
  # with same key value, which is legal in CGI.
  #
  # So in general values of this hash will be an array.
  # ContextObject.new_from_form_vars is good with that. 
  # Exception is url_ctx_fmt and url_ctx_val, which we'll
  # convert to single values, because ContextObject wants it so. 
  def self.context_object_params(a_rails_request)
    require 'cgi'
    
    # GET params
    co_params = CGI::parse( a_rails_request.query_string )    
    # add in the POST params please
    co_params.merge!(  CGI::parse(a_rails_request.raw_post)) if a_rails_request.raw_post
    # default value nil please, that's what ropenurl wants
    co_params.default = nil

    # CGI::parse annoyingly sometimes puts a nil key in there, for an empty
    # query param (like a url that has two consecutive && in it). Let's get rid
    # of it please, only confuses our code. 
    co_params.delete(nil)

    # Exclude params that are for Rails or Umlaut, and don't belong to the
    # context object. 
    excluded_keys = ["action", "controller", "page", /^umlaut\./, 'rft.action', 'rft.controller']
    co_params.keys.each do |key|
      excluded_keys.each do |exclude|
        co_params.delete(key) if exclude === key;
      end
    end
    # 'id' is a special one, cause it can be a OpenURL 0.1 key, or
    # it can be just an application-level primary key. If it's only a
    # number, we assume the latter--an openurl identifier will never be
    # just a number.
    if co_params['id']
      co_params['id'].each do |id|       
        co_params['id'].delete(id) if id =~ /^\d+$/ 
      end
    end

    return co_params
  end

  # Method that registers the dispatch status of a given service participating
  # in this request.
  # 
  # Status can be true (shorthand for DispatchedService::Success), false
  # (shorthand for DispatchedService::TemporaryError), or one of the other
  # DispatchedService status codes.
  # If a DispatchedService row already exists in the db, that row will be
  # re-used, over-written with new status value.
  #
  # Exception can optionally be provided, generally with failed statuses,
  # to be stored for debugging purposes.  
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
  

  # Create a ServiceResponse and it's associated ServiceType(s) object,
  # attached to this request.
  # First arg is a hash of key/values. Keys MUST include :service, with the
  # value being the actual Service object, not just the ID.
  # Other keys are as conventional for the service. 
  # 
  # second arg is an array of ServiceTypeValue objects, or
  # an array of 'names' of ServiceTypeValue objects. Ie,
  # ServiceTypeValue[:fulltext], or "fulltext" both work. A ServiceResponse
  # can be registered as being of more than one type, is why this is an array.
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
    #stypes = []
    unless service_type.empty?
      service_type.each do | st |
        #stype = ServiceType.find(:first, :conditions=>{:request_id => self.id, :service_response_id => svc_resp.id,:service_type => st})
        
        #unless stype
          stype = ServiceType.new(:request => self, :service_response => svc_resp, :service_type_value => st)
          stype.save!
          #stypes << stype
        #end
      end
    end
    #return stypes
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
             data['date'].blank? &&
        # pmid or doi is considered article-level, because SFX can
        # respond to those. Other identifiers may be useless. 
        (! referent.identifiers.find {|i| i =~ /^info\:(doi|pmid)/})
        )
  end

  # pass in string name of a service type value, get back list of
  # ServiceType objects with that value belonging to this request.
  # :refresh=>true will force a trip to the db to get latest values.
  # otherwise, association is used. 
  # This one does make a db call, to get most up to date list.
  # Should return empty array, never nil. 
  def get_service_type(svc_type, options = {})

    if ( options[:refresh])
      return self.service_types.find(:all,
                                :conditions =>
                                   ["service_type_value_id = ?",
                                   ServiceTypeValue[svc_type].id ],
                                :include => [:service_response]   
                                )
    else
      # find on an assoc will go to db, unless we convert it to a plain
      # old array first.
      return self.service_types.to_a.find_all { |st|  
       st.service_type_value == ServiceTypeValue[svc_type] }      
    end
  end
  
  protected

  # Called by self.new_request, if a new request _really_ needs to be created.
  def self.create_new_request!( args )

    # all of these are required
    params = args[:params]
    session = args[:session]
    a_rails_request = args[:rails_request]
    contextobj_fingerprint = args[:contextobj_fingerprint]
    context_object = args[:context_object]

    # We don't have a complete Request, but let's try finding
    # an already existing referent and/or referrer to use, if possible, or
    # else create new ones. 
      
    rft = nil
    if ( params['umlaut.referent_id'])
       rft = Referent.find(:first, :conditions => {:id => params['umlaut.referent_id']})
    end


    # Find or create a referrer, if we have a referrer in our OpenURL
    rfr = nil
    rfr = Referrer.find_or_create_by_identifier(context_object.referrer.identifier) unless context_object.referrer.empty? || context_object.referrer.identifier.empty?

    # No id given, or no object found? Create it. 
    unless (rft )
      rft = Referent.find_or_create_by_context_object(context_object, rfr)
    end

    # Create the Request
    req = Request.new
    req.session_id = session.session_id
    req.contextobj_fingerprint = contextobj_fingerprint
    # Don't do this! It is a performance problem.
    # rft.requests << req
    # (rfr.requests << req) if rfr
    # Instead, say it like this:
    req.referent = rft
    req.referrer = rfr

    # Save client ip
    req.client_ip_addr = params['req.ip'] || a_rails_request.remote_ip()
    req.client_ip_is_simulated = true if req.client_ip_addr != a_rails_request.remote_ip()

    # Save selected http headers, keep some out to avoid being too long to
    # serialize. 
    req.http_env = {}
    a_rails_request.env.each {|k, v| req.http_env[k] = v if ((k.slice(0,5) == 'HTTP_' && k != 'HTTP_COOKIE') || k == 'REQUEST_URI' || k == 'SERVER_NAME') }
    
    req.save!
    return req
  end

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

  # Input is a CGI::parse style of HTTP params (array values)
  # output is a string "fingerprint" canonically representing the input
  # params, which can be stored in the db, so that when another request
  # comes in, we can easily see if this exact request was seen before.
  #
  # This method will exclude certain params that are not part of the context
  # object, or which we do not want to consider for equality, and will
  # then serialize in a canonical way such that two co's considered
  # equivelent will have equivelent serialization. 
  def self.co_params_fingerprint(params)
    # Don't use ctx_time, consider two co's equal if they are equal but for ctx_tim. 
    excluded_keys = ["action", "controller", "page", /^umlaut\./,  "rft.action", "rft.controller", "ctx_tim"]
    # "url_ctx_val", "request_xml"
    
    # Hash.sort will do a first run through of canonicalization for us
    # production an array of two-element arrays, sorted by first element (key)
    params = params.sort
    
    # Now exclude excluded keys, and sort value array for further
    # canonicalization
    params.each do |pair|
      # CGI::parse().sort sometimes leaves us a value string with nils in it,
      # annoyingly. Especially for malformed requests, which can happen.
      # Remove them please.
      pair[1].compact! if pair[1]
      
      # === works for regexp and string
      if ( excluded_keys.find {|exc_key| exc_key === pair[0]}) 
        params.delete( pair )
      else
          pair[1].sort! if (pair[1] && pair[1].respond_to?("sort!"))
      end
    end
    
    # And YAML-ize for a serliazation
    serialized = params.to_yaml

    
    # And make an MD5 hash/digest. Why store the whole thing if all we need to
    # do is look it up? hash/digest works well for this.
    require 'digest/md5'
    return Digest::MD5.hexdigest( serialized )    
  end

  

end
