# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  require 'openurl'

  
  # Pick a unique cookie name to distinguish our session data from others'
  session :session_key => '_u2_session_id'
  before_filter :app_before_filter

  # This is SUPPOSED to default to 'false'. For our partial html snippet thing. 
  #def default_url_options(some_param)
  #  { :only_path => false }
  #end


  # Default error page. Individual controllers can over-ride. 
  def rescue_action_in_public(exception)
      # search error works. 
      render :template => "error/search_error", :status=>500, :layout=>AppConfig.param("search_layout","search_basic")
  end
  
  def app_before_filter
    
    @use_umlaut_journal_index = AppConfig.param("use_umlaut_journal_index", true)

    # We have an apache redir workaround to fix EBSCO illegal URLs.
    # But it ends up turning all "&" to "&amp;" as seperators in 
    # query portion of url. 
    # which makes rails add all these weird request params named 'amp' or 
    # 'amp;[something]'. Along with, strangely, the 'correct' params too.
    # So we strip the weird ones out. 
    if ( request.query_string =~ /\&amp\;/)
      params.keys.each do |param|
        params.delete( param ) if param == 'amp' || param =~ /^amp\;/
      end
    end

   return true
  end

  # helper method we need available in controllers too
  # Absolute URL for permalink for given request.
  # Have to supply rails request and umlaut request.
  protected
  helper_method :permalink_url
  def permalink_url(rails_request, umlaut_request)
    # if we don't have everything, we can't make a permalink. 
    unless (umlaut_request && umlaut_request.referent &&
            umlaut_request.referent.permalinks &&
            umlaut_request.referent.permalinks[0] )

            return nil
    end
    
    return url_for(:controller=>"store",    
        :id=>umlaut_request.referent.permalinks[0].id,
        :only_path => false )
        
  end

     
end

  # A good place as any to put some monkey patching?
  # This method originally defined in activerecord/lib/active_record/connection_adapters/abstract/connection_specification.rb
  # Has a bug, doesn't work when AR concurrency is set on. See:
  # http://dev.rubyonrails.org/ticket/7579
  # Monkey patching to fix. 
  module ActiveRecord
     class Base
       class << self

       def clear_reloadable_connections!
         if @@allow_concurrency           
           # Hash keyed by thread_id in @@active_connections. Hash of hashes.
 		       @@active_connections.each do |thread_id, conns| 
 		         conns.each do |name, conn| 
 		           if conn.requires_reloading? 
 		             conn.disconnect! 
 		             @@active_connections[thread_id].delete(name) 
               end 
 		         end 
	         end 
	       else
           # Just one level hash, no concurrency. 
 	         @@active_connections.each do |name, conn| 
             if conn.requires_reloading?
	             conn.disconnect! 
               @@active_connections.delete(name) 
 	  	       end 
 	         end
 	       end
	     end 
     end
     end  
  end
