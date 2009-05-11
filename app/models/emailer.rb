class Emailer < ActionMailer::Base
 # make note of the headers, content type, and time sent
 # these help prevent your email from being flagged as spam
  
  def citation(recipient, title, holdings)
    email = "bobcat@library.nyu.edu"
    @recipients   = recipient
    @from         = email
    headers         "Reply-to" => email
    @subject      = "BobCat result"
    @sent_on      = Time.now
    @content_type = "text/html"
 
    body[:title]  = title
    body[:holdings]  = holdings
  end
  
  def short_citation(recipient, title, location, call_number)
    email = "bobcat@library.nyu.edu"
    @recipients   = recipient
    @from         = email
    headers         "Reply-to" => email
    @subject      = "BobCat result"
    @sent_on      = Time.now
    @content_type = "text/plain"
 
    body[:title]  = title
    body[:location]  = location
    body[:call_number]  = call_number
  end
  
end
