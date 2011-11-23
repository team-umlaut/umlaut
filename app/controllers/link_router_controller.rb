# All clicks on a ServiceResponse are actually sent through this controller,
# which redirects to actual destination. That allows statistic logging,
# as well as special behavior (like EZProxy redirection, or showing in a
# bannered frameset). 
require 'cgi'
class LinkRouterController < ApplicationController
  def index

    # Capture mysterious exception for better error reporting. 
    begin
      svc_response = ServiceResponse.find(params[:id])
    rescue ActiveRecord::RecordNotFound => exception
      # Usually this happens when it's a spider trying an old link. "go" links
      # don't stay good forever! Bad spider, ignoring our robots.txt.
      
      logger.warn("LinkRouter/index not found exception!: #{exception}\nReferrer: #{request.referer}\nUser-Agent:#{request.user_agent}\nClient IP:#{request.remote_addr}\n\n")

      error_404
      return            
    end


    @collection = self.create_collection         

    clickthrough = Clickthrough.new
    clickthrough.request_id = svc_response.request_id
    clickthrough.service_response_id = svc_response.id
    clickthrough.save


    redirect_to calculate_url_for_response(svc_response)
  end
  
  protected
  
  # Must return a Hash where each key is a unique service name, and
  # each value a hash that defines a service. Like the hash in services.yml
  # under default/services.  By default, this method in fact just loads
  # and returns that hash, but can be over-ridden with local logic for
  # determining proper list of services for current request.
  #
  # Local over-ride could even in theory return a custom subclass of Collection, 
  # with customized dispatch behavior. Probably not a great idea though.  
  def create_collection    
    # trim out ones with disabled:true
    services = ServiceStore.config["default"]["services"].reject {|id, hash| hash["disabled"] == true}
            
    return Collection.new(@user_request, services)
  end
  
  
  # Used to calculate a destination/target url for an Umlaut response item.
  #
  # Pass in a ServiceType join object (not actually a ServiceResponse, sorry)
  # Calculates the URL for it, and then runs our link_out_filters on it,
  # returning the final calculated url. 
  #
  # Also requires a rails 'params' object, since url calculation sometimes
  # depends on submitted HTTP params.
  #
  # Used from LinkController's index,
  def calculate_url_for_response(svc_response)
      svc = ServiceStore.instantiate_service!(svc_response.service_id, nil)
      
      destination =  svc.response_url(svc_response, params)

      # if response_url returned a string, it's an external url and we're
      # done. If it's something else, usually a hash, then pass it to
      # url_for to generate a url.
      if destination.kind_of?(String)
        url = destination

        # Call link_out_filters, if neccesary.
        # These are services listed as  task: link_out_filter  in services.yml
        (1..9).each do |priority|
          @collection.link_out_service_level( priority ).each do |filter|
            filtered_url = filter.link_out_filter(url, svc_response)
            url = filtered_url if filtered_url
          end
        end
        return url
      else        
        return url_for(params_preserve_xhr(destination))
      end
  end

  
   
end
