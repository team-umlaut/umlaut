# Requests to the Resolve controller are OpenURLs.
# There is one exception: Instead of an OpenURL, you can include the
# parameter umlaut.request_id=[some id] to hook up to a pre-existing
# umlaut request (that presumably was an OpenURL). 

class ResolveController < ApplicationController
  before_filter :init_processing
  after_filter :save_request
  
  # Take layout from config, default to resolve_basic.rhtml layout. 
  layout AppConfig.param("resolve_layout", "resolve_basic")
  require 'json/lexer'
  require 'json/objects'
  require 'oai'
  require 'open_url'
  require 'collection'

  # Divs to be updated by the background updater. See background_update.rjs
  # Sorry that this is in a class variable for now, maybe we can come up
  # with a better way to encapsulate this info.
  @@background_divs = [ { :div_id => "fulltext", :partial => "fulltext", :service_type_value => "fulltext"},
                        { :div_id => "holding", :partial => "holding", :service_type_value => "holding"} ]

  # Retrives or sets up the relevant Umlaut Request, and returns it. 
  def init_processing
    # First see if this HTTP request told us to use an already existing Umlaut request
    # Sorry that this is an illegal OpenURL
    begin 
      request_id = params['umlaut.request_id']
      # Be sure to use session id too to guard against spoofing by guessing
      # request ids from another session.
      #require 'ruby-debug'
      #debugger
      @user_request = Request.find(:first, :conditions => ["session_id = ? and id = ?", session.session_id, request_id] ) unless request_id.nil? || @user_request
    rescue  ActiveRecord::RecordNotFound
      # Bad request id? Okay, pretend we never had a request_id at all. 
      request_id = nil
      @user_request = nil
    end

    # Only if we didn't load a request from umlaut.request_id...
    @user_request ||= Request.new_request(params, session )
    @collection = Collection.new(request.remote_ip, session)      
    @user_request.save    
  end

  def save_request
    @user_request.save!
  end
 		
  def index
    #self.init_processing # handled by before_filter 
    self.service_dispatch()
    @user_request.save! # should be handled by after_filter?
  end

  
  def json
  	self.index
  	@dispatch_hash = {:umlaut_response=>{:id => @requested_context_object.id}}
  	@dispatch_response.instance_variables.each { |ir |
  		@dispatch_hash[:umlaut_response][ir.to_s.gsub(/^@/, '')] = @dispatch_response.instance_variable_get(ir)
  	}
  	@headers["Content-Type"] = "text/javascript; charset=utf-8"
  	render_text @dispatch_hash.to_json 
		@context_object_handler.store(@dispatch_response)  	
  end

  # Action called by AJAXy thing to update resolve menu with
  # new stuff that got done in the background. 
  def background_update
    # Might be a better way to store/pass this info.
    # Divs that may possibly have new content. 
    @divs = @@background_divs || []
    # Now fall through to background_update.rjs
  end

  # Display a non-javascript background service status page--or
  # redirect back to index if we're done.
  def background_status

    unless ( @user_request.any_services_in_progress? )
      # Just redirect to ordinary index, no need to show progress status. 
      # Re-construct the original request url
      params_hash = @user_request.original_co_params(:add_request_id => true)
            
      redirect_to(params_hash.merge({:controller=>"resolve", :action=>'index'}))
    else
      # If we fall through, we'll show the background_status view, a non-js
      # meta-refresh update on progress of background services.
      # Your layout should respect this instance var--it will if it uses
      # the resolve_head_content partial, which it should.
      @meta_refresh_self = 5  
    end
  end
  
  def xml
		self.index
		umlaut_doc = REXML::Document.new
		root = umlaut_doc.add_element 'umlaut', 'id'=>@context_object_handler.id
		co_doc = REXML::Document.new @context_object.xml
		root.add co_doc.root
		umlaut_doc = @dispatch_response.to_xml(umlaut_doc)
  	@headers["Content-Type"] = "text/xml; charset=utf-8"
  	render_text umlaut_doc.write
		@context_object_handler.store(@dispatch_response)  	
  end  
  
  def description
  	service_dispatcher = self.init_processing 
    service_dispatcher.add_identifier_lookups(@context_object)
    service_dispatcher.add_identifier_lookups(@context_object)    
    service_dispatcher << AmazonService.new
    service_dispatcher << ServiceBundle.new(service_dispatcher.get_opacs(@collection))  	
    service_dispatcher.add_social_bookmarkers  	    
  	self.do_processing(service_dispatcher)  	 	
  end
  
  def web_search
  	service_dispatcher = self.init_processing
    service_dispatcher.add_identifier_lookups(@context_object)
    service_dispatcher << ServiceBundle.new(service_dispatcher.get_link_resolvers(@collection) + service_dispatcher.get_opacs(@collection))  	
    service_dispatcher.add_search_engines    
  	self.do_processing(service_dispatcher)  	     
  end
  
  def more_like_this
  	service_dispatcher = self.init_processing
    service_dispatcher.add_identifier_lookups(@context_object)
    service_dispatcher << ServiceBundle.new(service_dispatcher.get_link_resolvers(@collection) + service_dispatcher.get_opacs(@collection))
    service_dispatcher.add_search_engines
    service_dispatcher.add_social_bookmarkers  	
  	self.do_processing(service_dispatcher)  	
  	puts @dispatch_response.dispatched_services.inspect
    @dispatch_response.dispatched_services.each { | svc |
      if svc.respond_to?('get_similar_items') and !@dispatch_response.similar_items.keys.index(svc.identifier.to_sym)
        svc.get_similar_items(@dispatch_response)
      end
    }

  	unless @params[:view]
  	 @params[:view] = @dispatch_response.similar_items.keys.first.to_s
  	 
  	end
  	puts @dispatch_response.similar_items.keys.inspect
  end
  def related_titles
  	service_dispatcher = self.init_processing
    service_dispatcher.add_identifier_lookups(@context_object)
    service_dispatcher << ServiceBundle.new(service_dispatcher.get_link_resolvers(@collection) + service_dispatcher.get_opacs(@collection))  	
   	self.do_processing(service_dispatcher)  	
  end
  
  def toc
  	self.index
  end
    
  def start
  	self.index
  	render :action=>'index'
  end
  
  def help
  	service_dispatcher = self.init_processing  
    service_dispatcher << ServiceBundle.new(service_dispatcher.get_link_resolvers(@collection))  	
   	self.do_processing(service_dispatcher)     
  end

  def rescue_action_in_public(exception)
    render :template => "error/resolve_error", :layout=>'search_standard' 
  end  
  
  def do_background_services
    if @params['background_id']
    	service_dispatcher = self.init_processing
    	background_service = BackgroundService.find_by_id(@params['background_id'])  
    	services = Marshal.load background_service.services
    	service_dispatcher << ServiceBundle.new(services)
    	self.do_processing(service_dispatcher)
 			@context_object_handler.store(@dispatch_response)			
 			background_service.destroy
      menu = []
      unless @dispatch_response.similar_items.empty?
        menu << 'umlaut-similar_items'
      end
      unless @dispatch_response.description.empty?
        menu << 'umlaut-description' 
      end
      unless @dispatch_response.table_of_contents.empty?
        menu << 'umlaut-table_of_contents'
      end
      unless @dispatch_response.external_links.empty?
        menu << 'umlaut-external_links'
      end    
      render :text=>menu.join(",") 	
  		history = History.find_or_create_by_session_id_and_request_id(session.session_id, @context_object_handler.id)
  		history.cached_response = Marshal.dump @dispatch_response
  
  		history.save      	
    else
      render :nothing => true    	
    end
  end
  
  protected
  
  def service_dispatch()
    # Foreground services
    (0..9).each do | priority |
      next if @collection.service_level(priority).empty?
 
      if AppConfig[:threaded_services]
        bundle = ServiceBundle.new(@collection.service_level(priority))
        bundle.handle(@user_request)            
      else          
        @collection.service_level(priority).each do | svc |
          svc.handle(@user_request) unless @user_request.dispatched?(svc)
        end
      end        
    end

    # Background services. First register them all as queued, so status
    # checkers can see that.
    ('a'..'z').each do | priority |
      @collection.service_level(priority).each do | service |
        @user_request.dispatched_queued(service)
      end
    end
    # Now we do some crazy magic, start a Thread to run our background
    # services. We are NOT going to wait for this thread to join,
    # we're going to let it keep doing it's thing in the background after
    # we return a response to the browser
    backgroundThread = Thread.new(@collection, @user_request) do | t_collection,  t_request|
      begin
        logger.info("Starting background services in Thread #{Thread.current.object_id}")
        ('a'..'z').each do | priority |
           service_list = t_collection.service_level(priority)
           next if service_list.empty?
           logger.info("background: Making service bundle for #{priority}")
           #debugger
           bundle = ServiceBundle.new( service_list )
           bundle.debugging = true
           bundle.handle( t_request )
           logger.info("background: Done handling for #{priority}")
        end
        logger.info("Background services complete")
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

