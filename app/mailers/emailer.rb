class Emailer < ActionMailer::Base
  include UmlautConfigurable
    
  self.umlaut_config = UmlautController.umlaut_config
  
  helper :application

  
  def citation(recipient, user_request, fulltexts, holdings)
    @title  = find_good_title(user_request.referent)
    @fulltexts  = fulltexts
    @holdings  = holdings
    @user_request = user_request
    
    mail(:to => recipient, 
         :from => umlaut_config.from_email_addr, 
         :'Reply-to' => umlaut_config.from_email_addr,
         :subject => "#{umlaut_config.app_name} result: #{find_good_title(user_request.referent)}")
  end
  
  def short_citation(recipient, user_request, location, call_number)
    
 
    @title  = find_good_title(user_request.referent)
    @location  = location
    @call_number  = call_number
    @user_request = user_request
    
    mail(:to => recipient, 
         :from => umlaut_config.from_email_addr,
         :'Reply-to' => umlaut_config.from_email_addr, 
         :subject => "#{umlaut_config.app_name} result")

  end

  protected
    def find_good_title(referent)
      citation = referent.to_citation
      if citation[:container_title]
        return citation[:container_title]
      else
        return "#{citation[:title]} / #{citation[:author]}" 
      end      
    end


  
end
