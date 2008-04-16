class StoreController < ApplicationController
  #require 'open_url'
  require 'openurl'
  def index
    
    perm = Permalink.find(params[:id])
    co = OpenURL::ContextObject.new


    unless ( perm.referent )
      # This permalink has been purged, sorry. we need to make this work better.
      RAILS_DEFAULT_LOGGER.error("Permalink request with missing referent. Returning 404. Permalink id: #{perm.id}")
      # For now, give em a generic 404. One is saved in public as part of standard Rails.
      
      render :file=>File.join(RAILS_ROOT,"public/404.html"), :layout=>false, :status=>404
      return
    end
    
    co.import_context_object(perm.referent.to_context_object)
    
    # We intentionally do not preserve original referrer sid
    # in the permalink. But let's add our own, to avoid confusion
    # over why the sid is missing in SFX statistics etc. 
    co.referrer.add_identifier('info:sid/umlaut.code4lib.org:permalink')

    # Let's add any supplementary umlaut params passed to us
    # Everything except the 'id' which we used for the Rails action. 
    new_params = params.clone
    new_params.delete(:id)
    # and add in our new action
    new_params[:controller] = 'resolve'
    new_params[:action] = 'index'
    
    redirect_to(co.to_hash.merge(new_params))
  end
end
