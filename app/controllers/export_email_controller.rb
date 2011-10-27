class ExportEmailController < ApplicationController
  filter_parameter_logging :email
  before_filter :load_objects
  layout (proc do |controller|         
     if (controller.request.xhr? ||
         controller.params["X-Requested-With"] == "XmlHttpRequest")
       nil
     else
       AppConfig.param("search_layout", "search_basic").to_s
     end
  end)

  def load_objects
    @svc_type = ServiceType.find(params[:id])
    @user_request = @svc_type.request if @svc_type
  end
  
  def email    

  end 
  
  def txt    

  end
  
  def reset
  end

  def send_email
    @email = params[:email]
    @fulltexts = @user_request.get_service_type('fulltext', { :refresh=>true })
    @holdings = @user_request.get_service_type('holding', { :refresh=>true })
    
      if valid_email?
        Emailer.citation(@email, @user_request, @fulltexts, @holdings).deliver 
        respond_to do |format|
          format.html {  render }
        end
      else
        @partial = "email"
        flash[:error] = email_validation_error
        redirect_to params_preserve_xhr(params.merge(:action => "email"))        
      end
    
  end
  
  def send_txt
    @number = params[:number]
    # Remove any punctuation or spaces etc
    @number.gsub!(/[^\d]/, '') if @number

    
    @provider = params[:provider]
    
    @email = "#{@number}@#{@provider}" unless @number.nil? or @provider.nil?

    @holding_id = params[:holding]
    
      if valid_txt_number? && valid_txt_holding?
        Emailer.short_citation(@email, @user_request, location(@holding_id), call_number(@holding_id)).deliver 

        render # send_txt.rhtml       
      else        
        flash[:error] = txt_validation_error        
        redirect_to params_preserve_xhr(params.merge(:action => "txt"))
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
