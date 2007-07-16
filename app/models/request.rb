class Request < ActiveRecord::Base
  
  has_many :dispatched_services
  # Order service_type joins (ie, service_responses) by id, so the first
  # added to the db comes first. Less confusing to have a consistent order.
  # Also lets installation be sure services run first will have their
  # responses show up first. 
  has_many :service_types, :order=>'id ASC'
  belongs_to :referent
  belongs_to :referrer

  def self.new_request(params, session )
    
    # First look in the db for a full request that had the exact same
    # params as this one, in the same session. That's a reload, use
    # the same request, already done.
    req = Request.find(:first, :conditions => ["session_id = ? and params = ?", session.session_id, params.to_yaml])
    return req if req

    # Nope, okay, we don't have a complete Request, but let's try finding
    # an already existing referent and/or referrer to use, if possible, or
    # else create new ones. 

    # Find or create a Referent
    context_object = OpenURL::ContextObject.new
    context_object.import_hash(params)
    rft = Referent.find_or_create_by_context_object(context_object)

    # Find or create a referrer, if we have a referrer in our OpenURL
    rfr = nil
    rfr = Referrer.find_or_create_by_identifier(context_object.referrer.identifier) unless context_object.referrer.empty?

    # Create the Request
    req = Request.new
    req.session_id = session.session_id
    req.params = params.to_yaml
    rft.requests << req
    (rfr.requests << req) if rfr
    req.save!


    
    return req
  end

  # Status can be true, false, or one of the DispatchedService status codes.
  def dispatched(service, status, exception=nil)
    ds = self.dispatched_services.find(:first, :conditions=>{:service_id => service.id})
    unless ds
      # For some reason, this way of creating wasn't working to set up
      # the relationship properly. I think maybe cause the save was failing
      # silently validation, due to null service_id.
      # This new way does instead.
      #ds = self.dispatched_services.new()
      ds = DispatchedService.new
      ds.service_id = service.id
      ds.status = status
      self.dispatched_services << ds
    end    
    ds.status = status

    if (exception)
      # Oops, that doesn't keep the backtrace, which is what we wanted. Doh!
      # ds.exception = exception.to_yaml if exception
      e_hash = Hash.new
      e_hash[:class_name] = exception.class.name
      e_hash[:message] = exception.message
      e_hash[:backtrace] = exception.backtrace
      ds.exception = e_hash.to_yaml
    end
    
    ds.save!
  end

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
        svc_resp.service_data = response_data[:service_data]
        
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
          stype = ServiceType.new(:request => self, :service_response => svc_resp, :service_type => st)
          stype.save!
        #end
      end
    end
  end    
end
