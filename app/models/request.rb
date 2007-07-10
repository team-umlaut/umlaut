class Request < ActiveRecord::Base
  
  has_many :dispatched_services
  has_many :service_types
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
  
  def dispatched(service, success, exception=nil)
    ds = self.dispatched_services.find(:first, :conditions=>{:service_id => service.id})
    unless ds
      # For some reason, this way of creating wasn't working to set up
      # the relationship properly. I think maybe cause the save was failing
      # silently validation, due to null service_id.
      # This new way does instead.
      #ds = self.dispatched_services.new()
      ds = DispatchedService.new
      ds.service_id = service.id
      ds.successful = success
      self.dispatched_services << ds
    end    
    ds.successful = success
    ds.exception = exception.to_yaml if exception

    ds.save!
  end
  
  def dispatched?(service)
    ds= self.dispatched_services.find(:first, :conditions=>{:service_id => service.id})
    return true if ds and ds.successful?
    return false
  end
  
  def add_service_response(response_data,service_type=[])
    unless response_data.empty?
      svc_resp = nil
      ServiceResponse.find(:all, :conditions=>{:service_id => response_data[:service].id, :response_key => response_data[:key], :value_string => response_data[:value_string],:value_alt_string => response_data[:value_alt_string]}).each do | resp |
        svc_resp = resp if YAML.load(resp.value_text.to_s) == YAML.load(response_data[:value_text].to_s)
      end
      unless svc_resp
        svc_resp = ServiceResponse.new
        svc_resp.service_id = response_data[:service].id
        svc_resp.response_key = response_data[:key]
        svc_resp.value_string = response_data[:value_string]
        svc_resp.value_alt_string = response_data[:value_alt_string]
        svc_resp.value_text = response_data[:value_text]           
        svc_resp.save
      end
    end
    unless service_type.empty?
      service_type.each do | st |
        stype = ServiceType.find(:first, :conditions=>{:request_id => self.id, :service_response_id => svc_resp.id,:service_type => st})
        unless stype
          stype = ServiceType.new(:request_id => self.id, :service_response_id => svc_resp.id, :service_type => st)
          stype.save
        end
      end
    end
  end    
end
