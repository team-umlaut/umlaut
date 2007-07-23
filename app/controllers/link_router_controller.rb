require 'cgi'
class LinkRouterController < ApplicationController
  def index
    svc_type = ServiceType.find(params[:id])    
    redirect_to ServiceList.get(svc_type.service_response.service_id).response_url(svc_type.service_response)
    clickthrough = Clickthrough.new
    clickthrough.request_id = svc_type.request_id
    clickthrough.service_response_id = svc_type.service_response_id
    clickthrough.save
  end
end
