# All clicks on a ServiceResponse are actually sent through this controller,
# which redirects to actual destination. That allows statistic logging,
# as well as special behavior (like EZProxy redirection, or showing in a
# bannered frameset). 
require 'cgi'
class LinkRouterController < ApplicationController
  def index

    # Capture mysterious exception for better error reporting. 
    begin
      svc_type = ServiceType.find(params[:id])
    rescue ActiveRecord::RecordNotFound => exception
      # Usually this happens when it's a spider trying an old link. "go" links
      # don't stay good forever! Bad spider, ignoring our robots.txt.
      
      logger.warn("LinkRouter/index not found exception!: #{exception}\nReferrer: #{request.referer}\nUser-Agent:#{request.user_agent}\nClient IP:#{request.remote_addr}\n\n")

      error_404
      return            
    end


    @collection = Collection.new(svc_type.request)          

    clickthrough = Clickthrough.new
    clickthrough.request_id = svc_type.request_id
    clickthrough.service_response_id = svc_type.service_response_id
    clickthrough.save


    url = calculate_url_for_response(svc_type)      
    redirect_to url

  end
   
end
