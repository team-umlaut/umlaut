module Admin
  class ServiceErrorsController < UmlautController
    
    def index
      # grab the earliest dispatch to see how far back our db goes
      @earliest_dispatch = DispatchedService.select("updated_at").
        order("updated_at").
        limit(1).
        first.
        updated_at
      
      
      errors_base = DispatchedService.
        where(:status => [DispatchedService::FailedFatal, DispatchedService::FailedTemporary])
      
      if params[:service_id]
        errors_base = errors_base.where(:service_id => params[:service_id])
      end
      
      if params[:q]
        errors_base = errors_base.where("exception_info #{" NOT " if params[:q_not]} like ?", "%#{params[:q]}%")
      end
      
      # will miraculously return a hash whose key is service_id, value
      # is count of failed service dispatches. 
      @failed_by_service = errors_base.select("service_id").        
        group("service_id").
        count
      
      # And get the most recent batch of failed services
      # kaminari page/per
      @offset = params[:offset].to_i 
      @limit = params[:per_page].to_i 
      @limit = 10 if @limit = 0
      
      @dispatched_services = errors_base.order("updated_at DESC").
        limit(@limit).offset(@offset)             
      @dispatched_services_count = errors_base.count
    end
    
    
  end  
end
