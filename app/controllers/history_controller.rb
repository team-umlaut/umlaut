class HistoryController < ApplicationController
  layout "layouts/request_standard"  
  require 'ropenurl'
	model :catalog
	model :protocol
	model :link_resolver	
	model :oai_provider	
  model :citeulike_client
  model :yahoo_my_web_service
	model :unalog_service
	model :connotea_service
		
	def initialize 
 		@dispatch_response = nil
	end
	
	def init_processing
 		unless session[:responses]
 		 session[:responses] = {}
 		end	
    @collection = Collection.new(request.remote_ip, session)  
 		if @params[:id]
 			@params['res_id'] = @params[:id]
 		end    
    @context_object_handler = ContextObjectHandler.new @params, session    
    @context_object = @context_object_handler.context_object
    service_dispatcher = ServiceDispatcher.new        
      
 	end
 	def do_processing(service_dispatcher)
		if @context_object_handler.current and @params[:cache] != "false"
			dispatch_response_cache = DispatchResponseCache.new(session, @context_object_handler.id)
			@dispatch_response = dispatch_response_cache.dispatch_response
			dispatch_response_cache.reconcile_missing_services(@context_object, service_dispatcher)
		else
			@dispatch_response = service_dispatcher.dispatch(@context_object)
		end			    		
		
	end	
	
	def index	
		service_dispatcher = self.init_processing
		#self.do_processing(service_dispatcher)
		@history = History.find_all_by_session_id(session.session_id)
	end
	
end
