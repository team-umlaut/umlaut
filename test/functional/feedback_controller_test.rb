require 'test_helper'
 
class FeedbackControllerTest < ActionController::TestCase
  setup do 
    @umlaut_request = fake_umlaut_request("/resolve?sid=google&auinit=S&aulast=Madsbad&atitle=Mechanisms+of+changes+in+glucose+metabolism+and+bodyweight+after+bariatric+surgery&id=doi:10.1016/S2213-8587(13)70218-3&title=The+Lancet+Diabetes+%26+Endocrinology&volume=2&issue=2&date=2014&spage=152&issn=2213-8587")    
    @umlaut_request.save!

    FeedbackController.umlaut_config.feedback ||= Confstruct::Configuration.new
    FeedbackController.umlaut_config.feedback.contacts ||= Confstruct::Configuration.new
    FeedbackController.umlaut_config.feedback.contacts[:example] = Confstruct::Configuration.new(
      :email_address => "librarian@example.org",
      :label => "Librarian"
    )
  end

  test "display feedback form" do
    get :new, :contact_id => "example"
    assert_response :success
    assert_template "feedback/new"
  end

  test "send feedback" do
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      post :create, :contact_id => 'example', :name => "Joe Example", :email => "joe@example.org", :feedback => "Some feedback", :request_id => @umlaut_request.id
    end
    email = ActionMailer::Base.deliveries.last

    assert_equal ["librarian@example.org"], email.to
    assert_equal ["joe@example.org"], email.reply_to
    assert email.body.include? "Some feedback"

    assert_present flash[:alert_success]

    assert_redirected_to(:controller => "resolve", :action => "index", :'umlaut.request_id' => @umlaut_request.id)
  end

  test "#create raises error on missing contact_id email" do
    assert_raise(FeedbackController::NoFeedbackEmailFoundException) do
      post :create, :name => "Joe Example", :email => "joe@example.org", :feedback => "Some feedback", :request_id => @umlaut_request.id
    end

    assert_raise(FeedbackController::NoFeedbackEmailFoundException) do
      post :create, :contact_id => "NO_SUCH_ID", :name => "Joe Example", :email => "joe@example.org", :feedback => "Some feedback", :request_id => @umlaut_request.id
    end    
  end

  test "#new raises error on missing contact_id email" do
    assert_raise(FeedbackController::NoFeedbackEmailFoundException) do
      get :new
    end

    assert_raise(FeedbackController::NoFeedbackEmailFoundException) do
      get :new, :contact_id => "NO_SUCH_ID"
    end    
  end
  


end