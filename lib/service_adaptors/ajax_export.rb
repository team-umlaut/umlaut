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
    service_data = {}
    controller = self.instance_variable_get("@controller")
    ajax_id = self.instance_variable_get("@ajax_id")
    service_data[:url] = "/#{controller}/#{ajax_id}" 
    service_data[:ajax_id] = ajax_id
    service_data[:controller] = controller;
    service_data[:display_text] = self.name
      
    request.add_service_response( {:service=>self, :display_text => service_data[:display_text], :notes=>service_data[:notes], :url=> service_data[:url], :ajax_id=> service_data[:ajax_id], :service_data=>service_data }, ['export_citation']  )

    return request.dispatched(self, true)
  end
  
end
