# All clicks on a ServiceResponse are actually sent through this controller,
# which redirects to actual destination. That allows statistic logging,
# as well as special behavior (like EZProxy redirection, or showing in a
# bannered frameset).
require 'cgi'
class LinkRouterController < UmlautController
  # Add resolve layout for handling errors.
  layout :resolve_layout

  def index
    # Capture mysterious exception for better error reporting.
    begin
      svc_response = ServiceResponse.find(params[:id])
    rescue ActiveRecord::RecordNotFound => exception
      # Usually this happens when it's a spider trying an old link. "go" links
      # don't stay good forever! Bad spider, ignoring our robots.txt.
      log_error_with_context(exception, :warn)
      raise exception# will be caught by top level rescue_from
    end
    @collection = self.create_collection
    clickthrough = Clickthrough.new
    clickthrough.request_id = svc_response.request_id
    clickthrough.service_response_id = svc_response.id
    clickthrough.save
    redirect_to calculate_url_for_response(svc_response)
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
  protected :calculate_url_for_response
end