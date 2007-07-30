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
    # Eager load the actual responses from service types for efficiency,
    # because we will certainly need them. 
    return @user_request.service_types.find(:all,
      :conditions => 
        ["service_type_value_id = ?", ServiceTypeValue[svc_type].id ],
      :include => [:service_response]   )
    
    #responses = []
    #@user_request.service_types.find(:all, :conditions=>["service_type_value_id = ?", ServiceTypeValue[svc_type].id ] ).each do | response |
    #  responses << response
    #end
    
    #return responses
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

  #def search_opac_for_title(request)
    # Disable the whole thing for now
  #  return false
    
  #  require 'sru'
  #  require 'uri'

  #  opac = ServiceList.get('Opac')

    
  #  if request.referent.metadata['jtitle']
  #    title = request.referent.metadata['jtitle'].gsub(/[^A-z0-9\s]/, '')
  #  elsif request.referent.metadata['btitle']
  #    title = request.referent.metadata['btitle'].gsub(/[^A-z0-9\s]/, '')
  #  elsif request.referent.metadata['title']
  #    title = request.referent.metadata['title'].gsub(/[^A-z0-9\s]/, '')
  #  else 
  #    return false
  #  end
  #  search = SRU::Client.new(opac.sru_url)
  #  results = search.search_retrieve('dc.title all "'+title+'"', #:recordSchema=>'mods', :startRecord=>1, :maximumRecords=>1)

    
  #  return false unless results.number_of_records > 0
  #  suffix = case results.number_of_records
  #           when 1 then ''
  #           else 'es'
  #           end
  #  link = "<ul><li><a href='http://gil.gatech.edu/cgi-bin/Pwebrecon.cgi?SAB1="
  #  link += URI.escape(title.gsub(/\s(and|or)\s/, ' '))
  #  link += "&BOOL1=all+of+these&FLD1=Title+%28TKEY%29&CNT=25&HIST=1' target='_blank'>"
  #  link += results.number_of_records.to_s
  #  link += " possible match" + suffix

    
  #  link += " in "+opac.display_name+"</a></li></ul>"
    
  #  return link
  # end
  
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
