require 'cgi'
class LinkRouterController < ApplicationController

  # Will be redirected to a bannered frameset link based on the value
  # of app config "link_with_frameset".  URL parameter
  # "umlaut.link_with_frameset=false" can suppress that.
  # See environment.rb-dist for instructions on setting
  # app parameter. .
  def index
    svc_type = ServiceType.find(params[:id])    

    clickthrough = Clickthrough.new
    clickthrough.request_id = svc_type.request_id
    clickthrough.service_response_id = svc_type.service_response_id
    clickthrough.save

    if ( link_with_frameset?(svc_type) )
      redirect_to( self.class.frameset_action_params(svc_type) )
    else
      redirect_to ServiceList.get(svc_type.service_response.service_id).response_url(svc_type.service_response)
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
    params.merge!( { :controller=>'resolve',
                     :action=>'bannered_link_frameset',
                     :'umlaut.request_id' => u_request.id,
                     :id=>svc_type.id})
    return params
  end

  protected 
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
end
