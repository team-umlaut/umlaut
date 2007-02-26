class Request < ActiveRecord::Base
  has_many :dispatched_services
  has_many :service_types
  belongs_to :referent
  belongs_to :referrer
  
  def self.new_request(params, session)
    context_object = OpenURL::ContextObject.new
    context_object.import_hash(params)
    puts context_object.kev
    rft = Referent.find_or_create_by_context_object(context_object)
    rfr_id = nil
    rfr_id = Referrer.find_or_create_by_identifier(context_object.referrer.identifier).id unless context_object.referrer.empty?
    req = Request.find_or_create_by_referent_id_and_session_id_and_referrer_id(rft.id, session.session_id, rfr_id)
    req.save
    return req
  end
  
  def dispatched(service, success)
    ds = self.dispatched_services.find(:first, :conditions=>["service_id = ?", service.id])
    unless ds
      ds = self.dispatched_services.create()
    end
    ds.service = service
    ds.successful = success
    ds.save
  end
  
  def dispatched?(service)
    self.dispatched_services.each do | ds |
      if (ds.service == service and ds.successful?)
        puts ds.inspect
        puts ds.service
        puts ds.successful?
        return true
      end
    end
    return false
  end
  
  def add_service_response(response_data,service_type=[])
    unless response_data.empty?
      svc_resp = nil
      ServiceResponse.find(:all, :conditions=>["service_id = ? and key = ? and value_string = ? and value_alt_string = ?", response_data[:service].id, response_data[:key], response_data[:value_string], response_data[:value_alt_string]]).each do | resp |
        svc_resp = resp if resp.value_text = response_data[:value_text]
      end
      unless svc_resp
        svc_resp = ServiceResponse.new
        svc_resp.service = response_data[:service]
        svc_resp.key = response_data[:key]
        svc_resp.value_string = response_data[:value_string]
        svc_resp.value_alt_string = response_data[:value_alt_string]
        svc_resp.value_text = response_data[:value_text]           
        svc_resp.save
      end
    end
    unless service_type.empty?
      service_type.each do | st |
        stype = ServiceType.find(:first, :conditions=>["request_id = ? and service_response_id = ? and service_type = ?",self.id, svc_resp.id, st])
        unless stype
          stype = ServiceType.new(:request_id => self.id, :service_response_id => svc_resp.id, :service_type => st)
          stype.save
        end
      end
    end
  end    
end
