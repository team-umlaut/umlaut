class ResolveController < ApplicationController
  # Take layout from config, default to resolve_basic.rhtml layout. 
  layout AppConfig.param("resolve_layout", "resolve_basic")
  require 'json/lexer'
  require 'json/objects'
  require 'oai'
  require 'open_url'
  require 'collection'

  def init_processing
    @user_request = Request.new_request(params, session )
    @collection = Collection.new(request.remote_ip, session)      
    @user_request.save
  end
 		
  def index
    self.init_processing
    self.service_dispatch('foreground')
    @user_request.save
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
  def service_dispatch(stage)
    if stage == 'foreground'
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
    end
  end
  
end
