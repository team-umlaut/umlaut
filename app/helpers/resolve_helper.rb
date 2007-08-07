module ResolveHelper
  def load_custom_partial(action, view)
    begin
      render :partial=>action+'_'+view
     rescue ActionView::ActionViewError
      render :partial=>action+'_default'
     end
  end

  # This one does make a db transaction, to get most up to date list. 
  def get_service_type(svc_type)
    
    return @user_request.service_types.find(:all,
      :conditions => 
        ["service_type_value_id = ?", ServiceTypeValue[svc_type].id ],
      :include => [:service_response]   )
          
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
    return true if get_service_type('fulltext').empty? and get_service_type('holding').empty?
    return false unless @user_request.referent.format == 'journal'
    if @user_request.referent.metadata['atitle'] and @user_request.referent.metadata['atitle'] != ''
      return false
    else
      return true
    end
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
end
