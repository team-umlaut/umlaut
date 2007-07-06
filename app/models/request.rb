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
    ds = self.dispatched_services.find(:first, :conditions=>{:service_id => service.id})
    unless ds
      ds = self.dispatched_services.new()
      # AR isn't setting the request_id above for some reason
      ds.request_id = self.id      
    end
    ds.service_id = service.id
    ds.successful = success
    ds.save
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
