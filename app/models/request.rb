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
    ds = self.dispatched_service    
    ds.service = service
    ds.successful = success
    ds.save
  end
  
  def dispatched?(service)
    self.dispatched_services.each do | ds |
      return true if ds.service == service
    end
    return false
  end
end
