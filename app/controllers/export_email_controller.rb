class ExportEmailController < ApplicationController
  filter_parameter_logging :email

  layout AppConfig.param("resolve_layout", "resolve_basic").to_s, 
         :except => [:banner_menu, :bannered_link_frameset, :partial_html_sections]
  
  def email
    @user_request = user_request(params[:id])
    
    respond_to do |format|
      format.js { render :action => "#{params[:action]}.rjs"} # txt.rjs
      format.html { render :action => "#{params[:action]}.rhtml"} # txt.rhtml
    end
  end 
  
  def txt
    @user_request = user_request(params[:id])
    
    respond_to do |format|
      format.js { render :action => "#{params[:action]}.rjs"} # txt.rjs
      format.html { render :action => "#{params[:action]}.rhtml"} # txt.rhtml
    end
  end
  
  def reset
  end

  def send_email
    @user_request = user_request(params[:id])
    @email = params[:txt][:email] unless params.nil? or params[:txt].nil? or params[:txt][:email].nil? or params[:txt][:email].empty?
    @title = params[:txt][:title] unless params.nil? or params[:txt].nil? or params[:txt][:title].nil? or params[:txt][:title].empty?
    @holdings = user_request(params[:id]).get_service_type('holding', { :refresh=>true })
    Emailer.deliver_citation(@email, @title, @holdings) if valid_email?
    respond_to do |format|
      if valid_email?
        format.js { render :action => "#{params[:action]}.rjs"} # txt.rjs
        format.html { render :action => "#{params[:action]}.rhtml"} # send_txt.rhtml
      else
        flash[:error] = email_validation_error
        format.js { render :action => "email.rjs", :id => params[:id], :format => params[:format] }
        format.html { render :action => "email.rhtml", :id => params[:id], :format => params[:format] }
      end
    end
  end
  
  def send_txt
    @user_request = user_request(params[:id])
    @number = params[:txt][:number] unless params.nil? or params[:txt].nil? or params[:txt][:number].nil? or params[:txt][:number].empty?
    @provider = params[:txt][:provider] unless params.nil? or params[:txt].nil? or params[:txt][:provider].nil? or params[:txt][:provider].empty?
    @email = "#{@number}@#{@provider}" unless @number.nil? or @provider.nil?

    @title = params[:txt][:title] unless params.nil? or params[:txt].nil? or params[:txt][:title].nil? or params[:txt][:title].empty?

    @holding_id = params[:txt][:holding] unless params.nil? or params[:txt].nil? or params[:txt][:holding].nil? or params[:txt][:holding].empty?
    
    Emailer.deliver_short_citation(@email, @title, location(@holding_id), call_number(@holding_id)) if valid_txt?
    respond_to do |format|
      if valid_txt?
        format.js { render :action => "#{params[:action]}.rjs"} # txt.rjs
        format.html { render :action => "#{params[:action]}.rhtml"} # send_txt.rhtml
      else
        flash[:error] = txt_validation_error
        format.js { render :action => "txt.rjs", :id => params[:id], :format => params[:format] }
        format.html { render :action => "txt.rhtml", :id => params[:id], :format => params[:format] }
      end
    end
  end
  
  private
    def valid_txt?
      return !(@number.nil? or @holding_id.nil?)
    end
    
    def valid_email?
      return !(@email.nil?)
    end
    
  def user_request(id)
    permalink = Permalink.find(id)
    referent = permalink.referent
    return referent.requests.first unless referent.nil?
  end
  
  def txt_validation_error
    rv = ""
    unless valid_txt?
      rv += "<div class=\"validation_errors\">"
      rv += "<span>Please provide the following:</span>"
      rv += "<ul>"
      rv += "<li>a valid number</li>" if @number.nil?
      rv += "<li>the item you wish to send</li>" if @holding_id.nil?
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
      rv += "<li>a valid email address</li>" if @email.nil?
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
