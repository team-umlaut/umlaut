# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  require 'openurl'

  
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_u2_session_id'
  before_filter :app_before_filter

  # This is SUPPOSED to default to 'false'. For our partial html snippet thing. 
  #def default_url_options(some_param)
  #  { :only_path => false }
  #end


  # Default error page. Individual controllers can over-ride. 
  def rescue_action_in_public(exception)
    status = 500
    @page_title = "Error!"
    # Weird way to specify class names. See.
    #http://dev.rubyonrails.org/ticket/6863
    if ( exception.kind_of?(::ActionController::RoutingError) ||
         exception.kind_of?(::ActionController::UnknownAction) ||
         exception.kind_of?(::ActionController::UnknownController))
         # UnknownController
         # url that didn't match. It's a 404 error. 
        status = 404
        @page_title = "Not Found!"
        @not_found_error = true
    end

    RAILS_DEFAULT_LOGGER.fatal("Error request URI: #{request.request_uri}")    
    
    # search error works. 
    render :template => "error/search_error", :status=>status, :layout=>AppConfig.param("search_layout","search_basic")
  end
  
  def app_before_filter
    
    @use_umlaut_journal_index = AppConfig.param("use_umlaut_journal_index", true)

    # We have an apache redir workaround to fix EBSCO illegal URLs.
    # But it ends up turning all "&" to "&amp;" as seperators in 
    # query portion of url. 
    # which makes rails add all these weird request params named 'amp' or 
    # 'amp;[something]'. Along with, strangely, the 'correct' params too.
    # So we strip the weird ones out. 
    if ( request.query_string =~ /\&amp\;/)
      params.keys.each do |param|
        params.delete( param ) if param == 'amp' || param =~ /^amp\;/
      end
    end

   return true
  end

  # Just returns a generic 404 page. Other people can redirect here if desired.
  # Uses generic 404 page already stored in public/404.html as rails convention.    
  def error_404    
    render :file=>File.join(RAILS_ROOT,"public/404.html"), :layout=>false, :status=>404
  end

  # Over-ride the log processing method to include referrer logging,useful
  # for debugging.
  def log_processing
    super
    if logger && logger.info?
      logger.info("  HTTP Referer: #{request.referer[0..100]}") if request && request.referer
      logger.info("  HTTP Referer: [none]") unless request && request.referer
    end
  end

  # Pass in a ServiceType join object, we generate the
  # url to the action to create a frameset banner of the link there.
  # pass in some extra Rails params if you like.
  helper_method :frameset_action_url
  def frameset_action_url(svc_type, extra_params = {})
    u_request = svc_type.request

    # Start with a nice context object
    original_co = u_request.to_context_object
    
    # Add our controller code and id references
    # We use 'umlaut.id' instead of just 'id' as a param to avoid
    # overwriting an OpenURL 0.1 'id' param! 
    params=   { :controller=>'resolve',
                :action=>'bannered_link_frameset',
                :'umlaut.request_id' => u_request.id,                     
                :'umlaut.id'=>svc_type.id}

    params.merge!(extra_params)

    return url_for_with_co(params, original_co)
    
  end
  

  # Pass in a hash of Rails params, plus a context object.
  # Get back a url suitable for calling those params in your
  # rails app, with the kev OpenURL context object tacked on
  # the end. This is neccesary instead of the naive hash
  # merge approach we were previously using, because
  # of possibility of multiple openurl kev query params
  # with same name.
  helper_method :url_for_with_co  
  def url_for_with_co(params, context_object)
    url = url_for(params)
    if (url.include?('?'))
      url += '&'
    else
      url += '?'
    end
              
    url += context_object.kev   

    return url
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
  # also potentially used from banner-frame pages to calculate
  # what url to put in content frame.
  helper_method :calculate_url_for_response
  def calculate_url_for_response(svc_type)
      url = ServiceList.get(svc_type.service_response.service_id).response_url(svc_type, params)
      
      # Call link_out_filters, if neccesary.
      # These are services listed as  task: link_out_filter  in services.yml
      (1..9).each do |priority|
        @collection.link_out_service_level( priority ).each do |filter|
          filtered_url = filter.link_out_filter(url, svc_type)
          url = filtered_url if filtered_url
        end
      end

      return url
  end

  
  # helper method we need available in controllers too
  # Absolute URL for permalink for given request.
  # Have to supply rails request and umlaut request.
  protected
  helper_method :permalink_url
  def permalink_url(rails_request, umlaut_request)
    # if we don't have everything, we can't make a permalink. 
    unless (umlaut_request && umlaut_request.referent &&
            umlaut_request.referent.permalinks &&
            umlaut_request.referent.permalinks[0] )

            return nil
    end
    
    return url_for(:controller=>"store",    
        :id=>umlaut_request.referent.permalinks[0].id,
        :only_path => false )
        
  end


     
end

 
