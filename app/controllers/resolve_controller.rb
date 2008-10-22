# Requests to the Resolve controller are OpenURLs.
# There is one exception: Instead of an OpenURL, you can include the
# parameter umlaut.request_id=[some id] to hook up to a pre-existing
# umlaut request (that presumably was an OpenURL). 

class ResolveController < ApplicationController
  before_filter :init_processing
  # Init processing will look at this list, and for actions mentioned,
  # will not create a @user_request if an existing one can't be found.
  # Used for actions meant only to deal with existing requests. 
  @@no_create_request_actions = ['background_update']
  after_filter :save_request
  
  # Take layout from config, default to resolve_basic.rhtml layout. 
  layout AppConfig.param("resolve_layout", "resolve_basic"), 
         :except => [:banner_menu, :bannered_link_frameset, :partial_html_sections]
  require 'json/lexer'
  require 'json/objects'

  # If a background service was started more than 30 seconds
  # ago and isn't finished, we assume it died.
  BACKGROUND_SERVICE_TIMEOUT = 30
  
  # set up names of partials for differnet blocks on index page
  @@partial_for_block = {}
  @@partial_for_block[:holding] = AppConfig.param("partial_for_holding", "holding")
  def self.partial_for_block ; @@partial_for_block ; end
  
   

  # Retrives or sets up the relevant Umlaut Request, and returns it. 
  def init_processing
    options = {}
    if (  @@no_create_request_actions.include?(params[:action])  )
      options[:allow_create] = false
    end  
    @user_request ||= Request.new_request(params, session, request, options )

    # If we chose not to create a request and still don't have one, bale out.
    return unless @user_request
    
    # Ip may be simulated with req.ip in context object, or may be
    # actual, request figured it out for us. 
    @collection = Collection.new(@user_request.client_ip_addr, session)      
    @user_request.save!

    # Set 'timed out' background services to dead if neccesary. 
    @user_request.dispatched_services.each do | ds |
        if ( (ds.status == DispatchedService::InProgress ||
              ds.status == DispatchedService::Queued ) &&
              (Time.now - ds.updated_at) > BACKGROUND_SERVICE_TIMEOUT)

              ds.store_exception( Exception.new("background service timed out (took longer than #{BACKGROUND_SERVICE_TIMEOUT} to run); thread assumed dead.")) unless ds.exception_info
              # Fail it temporary, it'll be run again. 
              ds.status = DispatchedService::FailedTemporary
              ds.save!
        end
    end
    
    return @user_request
  end

  # Expire expired service_responses if neccesary.
  # See app config params 'response_expire_interval' and
  # 'response_expire_crontab_format'. 
    
  def expire_old_responses
    require 'CronTab'
    
    expire_interval = AppConfig.param('response_expire_interval')
    crontab_format = AppConfig.param('response_expire_crontab_format')

    unless (expire_interval || crontab_format)      
      # Not needed, nothing to expire
      return nil
    end
    
    responses_expired = 0
    @user_request.dispatched_services.each do |ds|

      now = Time.now
      
      expired_interval = expire_interval && 
        (now - ds.created_at > expire_interval)
      expired_crontab = crontab_format && 
        (now > CronTab.new(crontab_format).nexttime(ds.created_at))
      
      # Only expire completed ones, don't expire in-progress ones! 
      if (ds.completed && ( expired_interval || expired_crontab ))
          
          # Need to expire. Delete all the service responses, and
          # the DispatchedService record, and service will be automatically
          # run again. 
          
          serv_id = ds.service.id
          expired_responses = @user_request.service_types.each do |st|
            
            if st.service_response.service.id == serv_id
              @user_request.service_types.delete(st)
              responses_expired += 1
              st.service_response.destroy
              st.destroy
            end
          end
          @user_request.dispatched_services.delete(ds)
          ds.destroy
      end
    end
  end

  def setup_banner_link
    # We keep the id of the ServiceType join object in param 'umlaut.id' for
    # banner frameset link type actions. Take it out and stick the object
    # in a var if available.    
    joinID = params[:'umlaut.id']
    
    @service_type_join = @user_request.service_types.find_all_by_id(joinID).first if joinID
    
    # default?    
    unless ( @service_type_join )
       
      @service_type_join = 
        @user_request.service_types.find_by_service_type_value_id(
      ServiceTypeValue[:fulltext].id )
    end

    

    unless @service_type_join 
       raise "No service_type_join found!. params[umlaut.id] == #{params[:'umlaut.id']}"
    end
    
  end

  def save_request
    @user_request.save!
  end
 		
  def index

    self.service_dispatch()

    # link is a ServiceType object
    link = should_skip_menu
    if ( ! link.nil? )
      if (params["umlaut.link_with_frameset"] !=  "false")
        url = frameset_action_url( link, {'umlaut.skipped_menu' => 'true'})
      else        
        new_params = { :controller => "link_router",
                   :action => "index",
                   :id => link.id }
      
        url = url_for(new_params)
      end
      redirect_to url
    else
      # Render configed view, if configed, or "index" view if not. 
      view = AppConfig.param("resolve_view", "resolve/index")
      render :template => view
    end

  end

  # inputs an OpenURL request into the system and stores it, but does
  # NOT actually dispatch services to provide a response. Will usually 
  # be called by software, not a human browser. Sometimes
  # it's useful to do this as a first step before redirecting the user
  # to the actual resolve action for the supplied request--for instance,
  # when the OpenURL metadata comes in a POST and can't be redirected. 
  def register_request
    # init before filter already took care of setting up the request.
    @user_request.save!

    # Return data in headers allowing client to redirect user
    # to view actual response. 
    headers["x-umlaut-request_id"] = @user_request.id
    headers["x-umlaut-resolve_url"] = url_for( :controller => 'resolve', :'umlaut.request_id' => @user_request.id )
    headers["x-umlaut-permalink_url"] = permalink_url( request, @user_request )

    # Return empty body. Once we have the xml response done,
    # this really ought to return an xml response, but with
    # no service responses yet available.
    render(:nothing => true)
  end

  # Useful for developers, generate a coins. Start from
  # search/journals?umlaut.display_coins=true
  # or search/books?umlaut.display_coins=true
  def display_coins

  end
  
  # Show a link to something in a frameset with a mini menu in a banner. 
  def bannered_link_frameset
  
      # Normally we should already have loaded the request in the index method,
      # and our before filter should have found the already loaded request
      # for us. But just in case, we can load it here too if there was a
      # real open url. This might happen on re-loads (after a long time or
      # cookie expire!) or in other weird cases.
      # If it's not neccesary, no services will be dispatched,
      # service_dispatch catches that. 
      self.service_dispatch()
      @user_request.save!
      
      self.setup_banner_link()
  end

  # The mini-menu itself. 
  def banner_menu
     self.setup_banner_link()
  end

  

  # Action called by AJAXy thing to update resolve menu with
  # new stuff that got done in the background. 
  def background_update
    unless (@user_request)
      # Couldn't find an existing request? We can do nothing.
      raise Exception.new("background_update could not find an existing request to pull updates from, umlaut.request_id #{params["umlaut.request_id"]}")
    end
    
    
    # Might be a better way to store/pass this info.
    # Divs that may possibly have new content.
    map = AppConfig.param("bg_update_map")
    divs = map[:divs] || []
    error_div = map[:error_div]

    # This method call render for us
    self.background_update_js(divs, error_div)     
  end

  # Display a non-javascript background service status page--or
  # redirect back to index if we're done.
  def background_status

    unless ( @user_request.any_services_in_progress? )
      
      # Just redirect to ordinary index, no need to show progress status.
      # Include request.id, but also context object kev. 
      
      params_hash = 
         {:controller=>"resolve",
          :action=>'index', 
          :'umlaut.skip_resolve_menu' => params['umlaut.skip_resolve_menu'],
          :'umlaut.request_id' => @user_request.id }
      
      url = url_for_with_co( params_hash, @user_request.to_context_object )
      
      redirect_to( url )
    else
      # If we fall through, we'll show the background_status view, a non-js
      # meta-refresh update on progress of background services.
      # Your layout should respect this instance var--it will if it uses
      # the resolve_head_content partial, which it should.
      @meta_refresh_self = 5  
    end
  end

  # This action is for external callers. An external caller _could_ get
  # data as xml or json or whatever. But Umlaut already knows how to render
  # it. What if the external caller wants the rendered content, but in
  # discrete letter packets, a packet of HTML for each ServiceTypeValue?
  # This does that, and also let's the caller know if background
  # services are still running and should be refreshed, and gives
  # the caller a URL to refresh from if neccesary.   
  
  def partial_html_sections
    # Tell our application_helper#url_for to generate urls with hostname
    @generate_urls_with_host = true

    # Force background status to be the spinner--default js way of putting
    # spinner in does not generally work through ajax techniques.
    @force_bg_progress_spinner = true

    
    @partial_html_sections = AppConfig.param("partial_html_map")
    # calculate in progress for each section
    @partial_html_sections.each do |section|
         type_names = []
         type_names << section[:service_type_value] if section[:service_type_value]
         type_names.concat( section[:service_type_values] ) if section[:service_type_values]
       
         complete =  type_names.find { |n| @user_request.service_type_in_progress?(n) }.nil?

         # Give us a complete count of results present
         response_count = 0;
         type_names.each do |type|
           response_count += @user_request.get_service_type(type).length
         end

         section[:response_count] = response_count
         section[:complete?] = complete
     end

    # Run the request if neccesary. 
    self.service_dispatch()
    @user_request.save!

    self.api_render()
    
  end
  
  def api

    # Run the request if neccesary. 
    self.service_dispatch()
    @user_request.save!

    api_render()
    
  end  


    
  def rescue_action_in_public(exception)
    render(:template => "error/resolve_error", :status => 500, :layout => AppConfig.param("resolve_layout", "resolve_basic")) 
  end  

  protected

  # Based on app config and context, should we skip the resolve
  # menu and deliver a 'direct' link? Returns nil if menu
  # should be displayed, or the ServiceType join object
  # that should be directly linked to. 
  def should_skip_menu
    # From usabilty test, do NOT skip if coming from A-Z list/journal lookup.
    # First, is it over-ridden in url?
    if ( params['umlaut.skip_resolve_menu'] == 'false')
      return nil
    elsif ( params['umlaut.skip_resolve_menu_for_type'] )      
      skip = {:service_types => params['umlaut.skip_resolve_menu_for_type'].split(",") }
      skip[:force] = true if params['umlaut.force_skip_resolve'] == "true"
    end
    
    # Otherwise if not from url, load from app config
    skip  ||= AppConfig.param('skip_resolve_menu', false) if skip.nil?

    

    if (skip.kind_of?( FalseClass ))
      # nope
      return nil
    end

    return_value = nil
    if (skip.kind_of?(Hash) )
      # excluded rfr_ids?
      exclude_rfr_ids = skip[:excluded_rfr_ids]
      rfr_id = @user_request.referrer && @user_request.referrer.identifier 
      return nil if exclude_rfr_ids != nil && exclude_rfr_ids.find {|i| i == rfr_id}

      # Services to skip for?
      skip[:service_types].each do | service |
        service = ServiceTypeValue[service] unless service.kind_of?(ServiceTypeValue)  

        candidates = 
        @user_request.service_types.find(:all, 
          :conditions => ["service_type_value_id = ?", service.id])
        # Make sure we don't redirect to any known frame escapers!
        candidates.each do |st|

          # Don't use it for direct link unless we know it can
          # handle frameset, or we've overridden that check. 
          # TODO: Or, if we've chosen not to link with frameset feature anyway.
          if (skip[:force] == true || ! known_frame_escaper?(st) ) 
            return_value = st
            break;
          end
        end
      end

      # But wait, make sure it's included in :services if present.
      if (return_value && skip[:services] )
        return_value = nil unless skip[:services].include?( return_value.service_response.service.id )
      end
    elsif (skip.kind_of?(Proc ))
      return_value = skip.call( :request => @user_request )
      
    else
      logger.error( "Unexpected value in app config 'skip_resolve_menu'; assuming false." )
    end

    
    return return_value;    
  end

  # Param is a ServiceType join object. Tries to identify when it's a 
  # target which refuses to be put in a frameset, which we take into account
  # when trying to put it a frameset for our frame menu!
  # At the moment this is just hard-coded in for certain SFX targets only,
  # that is works for SFX targets only. We should make this configurable
  # with a lambda config.
  helper_method :'known_frame_escaper?'
  def known_frame_escaper?(service_type)

    bad_target_regexps = AppConfig.param('frameset_problem_targets')[:sfx_targets]
        
    bad_url_regexps = AppConfig.param('frameset_problem_targets')[:urls]
    
    response = service_type.service_response
    
    # We only work for SFX ones right now. 
    unless response.service.kind_of?(Sfx)      
      # Can't say it is, nope. 
      return false;
    end
    
    sfx_target_name = response.service_data[:sfx_target_name]
    url = response.url
    
    # Does our target name match any of our regexps?
    bad_target =  bad_target_regexps.find_all {|re| re === sfx_target_name  }.length > 0
    
    return bad_target if bad_target
    # Now check url if neccesary
    return bad_url_regexps.find_all {|re| re === url  }.length > 0    
  end
  
  # Helper method used here in controller for outputting js to
  # do the background service update. 
  def background_update_js(div_list, error_div_info=nil)
    render :update do |page|
    
        # Calculate whether there are still outstanding responses _before_
        # we actually output them, to try and avoid race condition.
        # If no other services are running that might need to be
        # updated, stop the darn auto-checker! The author checker watches
        # a js boolean variable 'background_update_check'.
        svc_types =  ( div_list.collect { |d| d[:service_type_value] } ).compact
        # but also use the service_type_values plural key
        svc_types = svc_types.concat( div_list.collect{ |d| d[:service_type_values] } ).flatten.compact
        
        keep_updater_going = false
        svc_types.each do |type|
          keep_updater_going ||= @user_request.service_type_in_progress?(type)
          break if keep_updater_going # good enough, we need the updater to keep going
        end

        # Stop the Prototype PeriodicalExecuter object if neccesary. 
        if (! keep_updater_going )
          page << "umlaut_background_executer.stop();"
        end
          
        # Now update our content -- we don't try to figure out which divs have
        # new content, we just update them all. Too hard to figure it out. 
        div_list.each do |div|
          div_id = div[:div_id]
          next if div_id.nil?
          # default to partial with same name as div_id
          partial = div[:partial] || div_id 
            
          page.replace_html div_id, :partial => partial
        end

        # Now update the error section if neccesary
        if ( ! error_div_info.nil? &&
             @user_request.failed_service_dispatches.length > 0 )
             page.replace_html(error_div_info[:div_id],
                               :partial => error_div_info[:partial])             
        end
    end
  end

  # Uses an "umlaut.response_format" param to return either
  # XML or JSON(p).  Assumes that a standardly rendered
  # Rails template is there to deliver XML, will convert it
  # to json using built in converters. 
  def api_render
    # Format?
    format = (params["umlaut.response_format"]) || "xml"
    
     if ( format == "xml" )      
        # The standard Rails template is assumed to return xml
        render(:content_type => "application/xml", :layout => false)
     elsif ( format == 'json' || format == "jsonp")        
        # get the xml in a string
        xml_str = render_to_string(:layout=>false)
        # convert to hash
        data_as_hash = Hash.from_xml( xml_str )
        # And conver to json. Ta-da!
        json_str = data_as_hash.to_json
  
        # Handle jsonp, deliver JSON inside a javascript function call,
        # with function name specified in parameters. 
        if ( format == "jsonp")
          procname = params["umlaut.jsonp"] || "umlautLoaded"          
          json_str = procname + "( " + json_str + " );"
        end  
        render(:text => json_str, :content_type=> "application/json",:layout=>false )
      else
        raise ArgumentError.new("format requested (#{format}) not understood by action #{params[:controller]} / #{params[:action]}")
      end    
  end

  def service_dispatch()
    expire_old_responses();

    # Register background services as queued before we do anything,
    # so if another request/refresh comes in to this same Umlaut
    # request, won't try and run them again.
    # Background services. First register them all as queued, so status
    # checkers can see that.
    ('a'..'z').each do | priority |
      @collection.service_level(priority).each do | service |
        @user_request.dispatched_queued(service)
      end
    end
    # Foreground services
    (0..9).each do | priority |
    
      next if @collection.service_level(priority).empty?
      
      bundle = ServiceBundle.new(@collection.service_level(priority), priority)
      bundle.handle(@user_request)            
    end
    
    # Got to reload cached referent values association, that the services
    # may have changed in another thread. 
    @user_request.referent.referent_values.reload

    # Now we run background services. 
    # Now we do some crazy magic, start a Thread to run our background
    # services. We are NOT going to wait for this thread to join,
    # we're going to let it keep doing it's thing in the background after
    # we return a response to the browser
    backgroundThread = Thread.new(@collection, @user_request) do | t_collection,  t_request|
      begin
        ('a'..'z').each do | priority |
           service_list = t_collection.service_level(priority)
           next if service_list.empty?
           bundle = ServiceBundle.new( service_list, priority )
           bundle.handle( t_request )           
        end        
     rescue Exception => e
        # We are divorced from any request at this point, not much
        # we can do except log it. Actually, we'll also store it in the
        # db, and clean up after any dispatched services that need cleaning up.
        # If we're catching an exception here, service processing was
        # probably interrupted, which is bad. You should not intentionally
        # raise exceptions to be caught here. 
        Thread.current[:exception] = e
        logger.error("Background Service execution exception: #{e}")
        logger.error( e.backtrace.join("\n") )
     end
    end
  end  
end

