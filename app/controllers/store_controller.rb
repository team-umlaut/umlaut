class StoreController < ApplicationController
  #require 'open_url'
  require 'openurl'
  def index
    
    perm = Permalink.find(:first, :conditions => { :id => params[:id]})
    co = OpenURL::ContextObject.new

    # We might have a link to a Referent in our db, or we might
    # instead have to rely on an XML serialized ContextObject in
    # the permalink, if the Referent has been purged. Either way
    # we're good. 
    referent = nil
    if ( perm && perm.referent)
      referent = perm.referent
    elsif (perm && perm.context_obj_serialized)
      stored_co = perm.restore_context_object
      referent = Referent.create_by_context_object( stored_co, :permalink => false )
      perm.referent = referent
      perm.save!
      perm.add_tag_uri!( referent )
    end
    

    unless ( referent )
      # We can't find a referent or succesfully restore an xml context
      # object to send the user to the request. We can not resolve
      # this permalink!
      
      RAILS_DEFAULT_LOGGER.error("Permalink request could not be resolved. Returning 404. Permalink id: #{perm.id}")
      
      render :file=>File.join(RAILS_ROOT,"public/404.html"), :layout=>false, :status=>404
      return
    end
    
    # Whether it was an already existing one, or a newly created one
    # turn it back to a co so we can add a few more things. 
    co.import_context_object(referent.to_context_object)
    
    # We intentionally do not preserve original referrer sid
    # in the permalink. But let's add our own, to avoid confusion
    # over why the sid is missing in SFX statistics etc.
    # This actually potentially creates problems as we won't trigger
    # the potentially appropriate custom SFX source parser. Hm. 
    co.referrer.add_identifier('info:sid/umlaut.code4lib.org:permalink')

    # Let's add any supplementary umlaut params passed to us
    # Everything except the 'id' which we used for the Rails action. 
    new_params = params.clone
    new_params.delete(:id)
    # and add in our new action
    new_params[:controller] = 'resolve'
    new_params[:action] = 'index'
    # Plus let's tell it about the referent, to make sure we get a referent
    # match even though we've changed the rfr_id etc.
    new_params[:'umlaut.referent_id'] = referent.id

    # Generate a Rails URL, then add on the KEV for our CO on the end
    # You might think you can just merge these into a hash and use url_for,
    # but Rails redirect_to/url_for isn't happy with multiple query params
    # with same name.

    redirect_to( url_for_with_co( new_params, co) )
  end
end
