# All clicks on a ServiceResponse are actually sent through this controller,
# which redirects to actual destination. That allows statistic logging,
# as well as special behavior (like EZProxy redirection, or showing in a
# bannered frameset). 
require 'cgi'
class LinkRouterController < ApplicationController
  # Will be redirected to a bannered frameset link based on the value
  # of app config "link_with_frameset".  URL parameter
  # "umlaut.link_with_frameset=false" can suppress that.
  # See environment.rb-dist for instructions on setting
  # app parameter. .
  def index

    @collection = Collection.new(request.remote_ip, session)      

    # Capture mysterious exception for better error reporting. 
    begin
      svc_type = ServiceType.find(params[:id])
    rescue ActiveRecord::RecordNotFound => exception
      logger.error("LinkRouter/index not found exception! (2) #{Time.now}: #{exception}\nReferrer: #{request.referer}\nUser-Agent:#{request.user_agent}\nClient IP:#{request.remote_addr}\n\n")
      # Just re-raise as usual, we have no useful way to recover, but
      # maybe this logging will help us debug.
      raise exception
    end

    clickthrough = Clickthrough.new
    clickthrough.request_id = svc_type.request_id
    clickthrough.service_response_id = svc_type.service_response_id
    clickthrough.save

    if ( link_with_frameset?(svc_type) )
      redirect_to( self.class.frameset_action_params(svc_type) )
    else
      url = ServiceList.get(svc_type.service_response.service_id).response_url(svc_type.service_response)
      
      # Call link_out_filters, if neccesary.
      # These are services listed as  task: link_out_filter  in services.yml
      (1..9).each do |priority|
        @collection.link_out_service_level( priority ).each do |filter|
          filtered_url = filter.link_out_filter(url, svc_type)
          url = filtered_url if filtered_url
        end
      end
            
      redirect_to url
    end
  end
    
  # Pass in a ServiceType join object, we generate the
  # hash to pass to link_to or url_for to create a 
  # frameset banner of the link there.
  def self.frameset_action_params(svc_type)
    u_request = svc_type.request

    # Start with a nice context object
    params = u_request.original_co_params
    
    # Add our controller code and id references
    # We use 'umlaut.id' instead of just 'id' as a param to avoid
    # overwriting an OpenURL 0.1 'id' param! 
    params.merge!( { :controller=>'resolve',
                     :action=>'bannered_link_frameset',
                     :'umlaut.request_id' => u_request.id,                     
                     :'umlaut.id'=>svc_type.id})
    return params
  end
  
  protected
  # Should a link be displayed inside our banner frameset?
  # Depends on config settings, url params, and 
  # whether the resolve menu was skipped or not. 
  def link_with_frameset?(svc_type)
    # Over-ridden in url?
    if ( params['umlaut.link_with_frameset'] == 'false' )
      config = false
    elsif ( params['umlaut.link_with_frameset'] == 'true')
      config = true
    end

    # Otherwise load from app config
    config = AppConfig.param("link_with_frameset", :standard) if config.nil?
    
    case config
      when TrueClass
        return true
      when FalseClass
        return false
      when :standard
        # 'Standard' behavior is frameset link only if we're coming
        # from a menu-skip, which is indicated with a URL param. 
        return params[:'umlaut.skipped_menu'] == true
      when Proc
        # Custom defined logic
        return config.call( :service_type_join => svc_type )
      else
        logger.error( "Unexpected value in app config 'link_with_frameset'; assuming false." )
        return false
      end    
  end

  def rescue_action_in_public(exception)
      # search error works. 
      render :template => "error/search_error", :layout=>AppConfig.param("search_layout","search_basic")
  end   
end
