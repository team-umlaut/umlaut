class FeedbackMailer < ActionMailer::Base
  add_template_helper(EmailerHelper)

  default from: UmlautController.umlaut_config.from_email_addr

  # feedback("findit.library.school.edu", "librarian@university.edu",:name => "Joe", :email => "joe@gmail.com", :feedback => "Whatever", :umlaut_request => urequest)
  #   * umlaut_request is optional     
  def feedback(host, to_address, options = {})
    @host = host
    @umlaut_request = options[:umlaut_request]
    @name     = options[:name]
    @email    = options[:email]
    @feedback = options[:feedback]

    # Force permalink creation if we don't have one already
    if @umlaut_request && @umlaut_request.referent.permalinks.empty?
      permalink = Permalink.new_with_values!(@umlaut_request.referent, @umlaut_request.referrer_id)            
      @umlaut_request.referent.permalinks << permalink
      @umlaut_request.save!
    end

    mail(:to => to_address, :subject => "#{UmlautController.umlaut_config.app_name} Feedback: #{options[:name]}", :reply_to => @email)
  end

end