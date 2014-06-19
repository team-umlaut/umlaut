class FeedbackController < UmlautController
  def new
    contact_email_lookup(params[:contact_id])
    # default render
  end

  def create    
    contact_config = contact_email_lookup(params[:contact_id])
    to_address = contact_config[:email_address]

    options = params.slice(:name, :email, :feedback)
    if params[:request_id] && umlaut_request = Request.find_by_id(params[:request_id])
      options = options.merge(
        :umlaut_request => umlaut_request
      )
    end

    FeedbackMailer.feedback(request.host_with_port, to_address, options).deliver

    flash[:alert_success] = "Thanks, your message has been sent."

    if umlaut_request
      redirect_to :controller => "resolve", :action => :index, "umlaut.request_id" => umlaut_request.id
    else
      redirect_to root_url
    end
  end

  protected
  def contact_email_lookup(contact_id)
    unless contact_id
      raise NoFeedbackEmailFoundException.new("Missing a contact_id, needed to look up feedback destination email.")
    end
    contact_config = umlaut_config.feedback && umlaut_config.feedback.contacts && umlaut_config.feedback.contacts[contact_id]

    unless contact_config && contact_config[:email_address]
      raise NoFeedbackEmailFoundException.new("Could not find feedback destination email for contact_id: `#{contact_id}`")
    end

    return contact_config
  end

  class NoFeedbackEmailFoundException < ArgumentError
  end

end