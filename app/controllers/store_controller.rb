class StoreController < UmlautController
  #require 'open_url'
  require 'openurl'

  # Add resolve layout for handling errors.
  layout :resolve_layout

  def index
    perm = Permalink.where(:id => params[:id]).first
    unless perm # not in our db
      handle_404_error
      return
    end

    co = OpenURL::ContextObject.new
    # We might have a link to a Referent in our db, or we might
    # instead have to rely on an XML serialized ContextObject in
    # the permalink, if the Referent has been purged. Either way
    # we're good.
    referent = nil
    if ( perm.referent)
      referent = perm.referent
    elsif ( perm.context_obj_serialized)
      stored_co = perm.restore_context_object
      # And a referrent, no referrer for now, we'll restore it later.
      referent = Referent.create_by_context_object( stored_co, :permalink => false )
      perm.referent = referent
    end

    unless ( referent )
      # We can't find a referent or succesfully restore an xml context
      # object to send the user to the request. We can not resolve
      # this permalink!
      handle_404_error
      return
      #raise NotFound.new("Permalink request could not be resolved. Returning 404. Permalink id: #{params[:id]}")
    end

    perm.last_access = Time.now # keep track of when permalink last actually retrieved
    # will catch possible new referent to be saved, as well as
    # update to last_access
    perm.save!

    # Whether it was an already existing one, or a newly created one
    # turn it back to a co so we can add a few more things.
    co.import_context_object(referent.to_context_object)

    # We preserve original referrer. Even though this isn't entirely accurate
    # this is neccesary to get SFX to handle it properly when we call to SFX,
    # including handling source-specific private data, etc.
    co.referrer.add_identifier( perm.orig_rfr_id ) if perm.orig_rfr_id

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