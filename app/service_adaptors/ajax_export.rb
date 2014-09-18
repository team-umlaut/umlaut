# This is an abstract superclass other services over-ride to get
# extra ajaxy windows upon click on link. 
class AjaxExport < Service
  required_config_params :ajax_id, :controller

  def initialize(config)
    super(config)
  end

  # Standard method, used by background service updater. See Service docs. 
  def service_types_generated
    types = [ ServiceTypeValue[:export_citation] ]
    
    return types
  end
  
  def handle(request)    
      
    request.add_service_response(:service=>self, 
      :display_text => @display_text,
      :display_text_i18n => @display_text_i18n,
      :link_supports_ajax_call => true,
      :notes=> @note,
      :service_type_value => 'export_citation'  )

    return request.dispatched(self, true)
  end

  def response_url(service_response, params)
    # Hash that caller will pass to url_for to create an internally
    # facing link.
    return {:controller=>@form_controller, 
     :action=>@form_action, 
     :id => service_response.id, 
     :format => params[:format]}
  end
  
end
