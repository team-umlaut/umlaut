class LinkRouterController < ApplicationController
  require 'cgi'
  def index
    svc_type = ServiceType.find(params[:id])    
    redirect_to svc_type.service_response.service.response_url(svc_type.service_response)
    clickthrough = Clickthrough.new
    clickthrough.request_id = svc_type.request_id
    clickthrough.service_response_id = svc_type.service_response_id
    clickthrough.save
  end
end
