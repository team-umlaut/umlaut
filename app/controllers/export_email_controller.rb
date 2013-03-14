class ExportEmailController < UmlautController

  before_filter :load_objects
  layout :search_layout_except_xhr

  def load_objects
    @svc_response = ServiceResponse.find(params[:id])
    @user_request = @svc_response.request if @svc_response
  end

  def send_email
    @email = params[:email]
    @fulltexts = @user_request.get_service_type('fulltext', { :refresh=>true })
    @holdings = @user_request.get_service_type('holding', { :refresh=>true })
    if valid_email?
      Emailer.citation(@email, @user_request, @fulltexts, @holdings).deliver
    else
      @partial = "email"
      flash[:alert] = email_validation_error
      render :email and return
    end
  end

  def send_txt
    @number = params[:number]
    # Remove any punctuation or spaces etc
    @number.gsub!(/[^\d]/, '') if @number
    @provider = params[:provider]
    @email = "#{@number}@#{@provider}" unless @number.nil? or @provider.nil?
    @holding = params[:holding]
    if valid_txt_number? && valid_txt_holding?
      Emailer.short_citation(@email, @user_request, holding_location(@holding_id), call_number(@holding_id)).deliver
    else
      flash[:alert] = txt_validation_error
      render :txt and return
    end
  end

  private
  def valid_txt_number?
    ((not @number.blank?) && @number.length == 10)
  end

  def valid_txt_holding?
    (not @holding.blank?)
  end

  def valid_email?
    (@email =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i)
  end

  def txt_validation_error
    errors = []
    errors << "a valid number" unless valid_txt_number?
    errors << "the item you wish to send" unless valid_txt_holding?
    errors
  end

  def email_validation_error
    errors = []
    errors << "a valid email address"
    errors
  end

  def holding(id)
    return ServiceResponse.find(id) unless id.nil?
  end

  def holding_location(id)
    return holding(id).view_data[:collection_str] unless holding(id).nil?
  end

  def call_number(id)
    return holding(id).view_data[:call_number] unless holding(id).nil?
  end
end