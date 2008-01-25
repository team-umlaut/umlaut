module ResolveHelper
  def load_custom_partial(action, view)
    begin
      render :partial=>action+'_'+view
     rescue ActionView::ActionViewError
      render :partial=>action+'_default'
     end
  end

  # Returns Array of ServiceType objects associated with current @user_request
  # (the Umlaut Request object), matching svc_type type. svc_type should be
  # a string name of ServiceTypeValue
  # delegates work to Request.get_service_type. 
  # This one does make a db transaction, to get most up to date list. 
  def get_service_type(svc_type)
    return @user_request.get_service_type(svc_type)
    #return @user_request.service_types.find(:all,
    #  :conditions => 
    #    ["service_type_value_id = ?", ServiceTypeValue[svc_type].id ],
    #  :include => [:service_response]   )
          
  end

  # Returns an array of DispatchedServices that are marked failed. 
  def failed_service_dispatches
    return @user_request.failed_service_dispatches
  end

  # Are there background services queued or in progress that might
  # return the service type? Please pass in a ServiceTypeValue, or
  # a String if you must (but just convert with ServiceTypeValue["string"],
  # why not?
  def service_type_in_progress?(svc_type)
    return @user_request.service_type_in_progress?(svc_type)
  end
  def service_types_in_progress?(array)
    return @user_request.service_types_in_progress?(array)
  end

  # True if dispatch table has statuses queued or in progress. 
  def any_services_in_progress?
    @user_request.any_services_in_progress?
  end
  
  def app_name
    return AppConfig.param("app_name", 'Find It')
  end

  
  def display_ill?
    # Local implementor can provide custom logic in environment. See
    # same environment file.
    custom_logic = AppConfig.param('resolve_display_ill')

    return true unless custom_logic

    return custom_logic.call(@user_request)
    
    #return true if get_service_type('fulltext').empty? and get_service_type('holding').empty?
    #return false unless @user_request.referent.format == 'journal'
    #if @user_request.referent.metadata['atitle'] and @user_request.referent.metadata['atitle'] != ''
    #  return false
    #else
    #  return true
    #end
  end
  
  def display_closest_web_results?  
    return '' unless (@action_name == 'index' or @action_name == 'start') and @dispatch_response.relevant_links.length > 0
    if @cookies[:umlaut_web_results] and @cookies[:umlaut_web_results] == 'false'
      return 'hideWebResults();'
    end
    if @cookies[:umlaut_web_results] and @cookies[:umlaut_web_results] == 'true'
      return 'showWebResults();'
    end
    if @context_object.referent.format == 'journal' and (@context_object.referent.metadata['atitle'].nil? or @context_object.referent.metadata['atitle'] == '')
      return 'hideWebResults();'
    end
    return 'showWebResults();'
  end

  # size can be 'small', 'medium', or 'large.
  # returns a ServiceResponse  object, or nil. 
  def cover_image_response(size='medium')
    cover_images = get_service_type('cover_image')
    cover_images.each do |st|
      return st if st.service_response[:size] == size 
    end
    return nil
  end

  # pass in a ServiceType object, usually for fulltext.
  # Returns a string URL that will take the user directly to
  # that resource. Actually through an umlaut redirect, but eventually. 
  def direct_url_for(service_type)
    url_for( :controller => 'link_router', :'id' => service_type.id , :'umlaut.link_with_frameset' => 'false' )      
  end

  # Used by banner menu pages. 
  # pass in a service_type object, get a link (<a>) to display it in a frameset
  # page. Takes account of known_frame_escapers to send them to a new non-framed
  # window.
  def frameset_link_to(service_type, url_params={})
    if ( known_frame_escaper?(service_type))
      link_to(service_type.view_data[:display_text],
              direct_url_for(service_type),
              'target'=>'_blank')
    else    
      link_to(service_type.view_data[:display_text],
              LinkRouterController::frameset_action_params( service_type ).merge( url_params ) ,
              'target'=> '_top')
    end
  end
  
  # Returns true if the current request is title-level only--if it has
  # no vol/iss/page number etc info.
  def title_level_request?  
    return @user_request.title_level_citation?
  end

  # Did this come from citation linker style entry?
  # We check the referrer. 
  def user_entered_citation?(uml_request)
    return false unless uml_request && uml_request.referrer
    
    id = uml_request.referrer.identifier
    return id == 'info:sid/sfxit.com:citation' || id == AppConfig.param('rfr_ids')[:citation] || id == AppConfig.param('rfr_ids')[:opensearch]
  end

  def display_not_found_warning?(uml_request)
    metadata = uml_request.referent.metadata
    
  
    return (metadata['genre'] != 'book' && metadata['object_id'].blank? && user_entered_citation?(@user_request) ) ? true : false
  end

    
end
