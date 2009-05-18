class ExportEmailController < ApplicationController
  filter_parameter_logging :email
  before_filter :load_objects
  layout AppConfig.param("search_layout", "search_basic").to_s

  def load_objects
    @svc_type = ServiceType.find(params[:id])
    @user_request = @svc_type.request if @svc_type
  end
  
  def email

    
    respond_to do |format|
      format.js { render :action => "show_modal_dialog.rjs"}
      format.html { @force_html_form = true ; render }
    end
  end 
  
  def txt

    
    respond_to do |format|
      format.js { render :action => "show_modal_dialog.rjs"}
      format.html { @force_html_form = true ; render }
    end
  end
  
  def reset
  end

  def send_email
    @email = params[:email]
    @holdings = @user_request.get_service_type('holding', { :refresh=>true })
    
    Emailer.deliver_citation(@email, @user_request, @holdings) if valid_email?
    respond_to do |format|
      if valid_email?
        format.js { render :action => "modal_dialog_success.rjs"}
        format.html {  render }
      else
        @partial = "email"
        @error = email_validation_error
        format.js { render :action => "show_modal_dialog.rjs", :id => params[:id], :format => params[:format] }
        format.html { render :action => "email.rhtml", :id => params[:id], :format => params[:format] }
      end
    end
  end
  
  def send_txt
    @number = params[:number]
    # Remove any punctuation or spaces etc
    @number.gsub!(/[^\d]/, '') if @number

    
    @provider = params[:provider]
    
    @email = "#{@number}@#{@provider}" unless @number.nil? or @provider.nil?

    @holding_id = params[:holding]
    
    respond_to do |format|      
      if valid_txt_number? && valid_txt_holding?
        Emailer.deliver_short_citation(@email, @user_request, location(@holding_id), call_number(@holding_id)) 
    
        format.js { render :action => "modal_dialog_success.rjs"} 
        format.html { @force_html_form = true ; render } # send_txt.rhtml
      else
        @partial = "txt"
        @error = txt_validation_error        
        format.js { render :action => "show_modal_dialog.rjs" }
        format.html { @force_html_form = true ; render :action => "txt.rhtml", :id => params[:id], :format => params[:format] }
      end
    end
  end
  
  private
    def valid_txt_number?
      return (! @number.blank?) && @number.length == 10
    end

    def valid_txt_holding?
       return ! @holding_id.blank?
    end
    
    def valid_email?
      return @email =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
    end
    
  
  def txt_validation_error
    rv = ""
    unless valid_txt_number? && valid_txt_holding?
      rv += "<div class=\"validation_errors\">"
      rv += "<span>Please provide the following:</span>"
      rv += "<ul>"
      rv += "<li>a valid number</li>" unless valid_txt_number?
      rv += "<li>the item you wish to send</li>" unless valid_txt_holding?
      rv += "</ul>"
      rv += "</div>"
    end
    return rv
  end
  
  def email_validation_error
    rv = ""
    unless valid_email?
      rv += "<div class=\"validation_errors\">"
      rv += "<span>Please provide the following:</span>"
      rv += "<ul>"
      rv += "<li>a valid email address</li>"
      rv += "</ul>"
      rv += "</div>"
    end
    return rv
  end

  def holding(id)
    return ServiceType.find(id) unless id.nil?
  end
  
  def location(id)
    return holding(id).view_data[:collection_str] unless holding(id).nil?
  end
    
  def call_number(id)
    return holding(id).view_data[:call_number] unless holding(id).nil?
  end




 
end
