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
      :link_supports_ajax_call => true,
      :notes=> @note,
      :service_type_value => 'export_citation'  )

    return request.dispatched(self, true)
  end

  def response_url(svc_type, params)
    # Hash that caller will pass to url_for to create an internally
    # facing link.
    debugger
    return {:controller=>@form_controller, 
     :action=>@form_action, 
     :id => svc_type, 
     :format => params[:format]}
  end
  
end
