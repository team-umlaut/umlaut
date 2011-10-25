class Emailer < ActionMailer::Base
 helper :application
 # make note of the headers, content type, and time sent
 # these help prevent your email from being flagged as spam
  
  def citation(recipient, user_request, fulltexts, holdings)
    @title  = find_good_title(user_request.referent)
    @fulltexts  = fulltexts
    @holdings  = holdings
    @user_request = user_request
    
    mail(:to => recipient, 
         :from => AppConfig.param("from_email_addr"), 
         :subject => "#{AppConfig.param("app_name")} result: #{find_good_title(user_request.referent)}")
  end
  
  def short_citation(recipient, user_request, location, call_number)
    email = AppConfig.param("from_email_addr")
    @recipients   = recipient
    @from         = email
    headers         "Reply-to" => email
    @subject      = "#{AppConfig.param("app_name")} result"
    @sent_on      = Time.now
    @content_type = "text/plain"
 
    @body["title"]  = find_good_title(user_request.referent)
    @body["location"]  = location
    @body["call_number"]  = call_number
    @body["user_request"] = user_request

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
