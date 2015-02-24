

require 'test_helper'
 
class FeedbackMailerTest < ActionMailer::TestCase
  setup do 
    ActionMailer::Base.deliveries.clear

    @host       = "umlaut.example.org"
    @to_email   = "librarian@example.org"
  end

  test "feedback" do
    umlaut_request = fake_umlaut_request("/resolve?sid=google&auinit=S&aulast=Madsbad&atitle=Mechanisms+of+changes+in+glucose+metabolism+and+bodyweight+after+bariatric+surgery&id=doi:10.1016/S2213-8587(13)70218-3&title=The+Lancet+Diabetes+%26+Endocrinology&volume=2&issue=2&date=2014&spage=152&issn=2213-8587")

    feedback_name  = "Joe Example"
    feedback_email = "joe@example.org"
    feedback_text = "This is my feedback, yes it is"

    email = FeedbackMailer.feedback(@host, @to_email, :umlaut_request => umlaut_request, :name => feedback_name, :email => feedback_email, :feedback => feedback_text).deliver

    assert ActionMailer::Base.deliveries.present?
    assert_equal [UmlautController.umlaut_config.from_email_addr], email.from
    assert_equal [feedback_email],           email.reply_to
    assert_equal [@to_email],       email.to
    assert_equal "#{UmlautController.umlaut_config.app_name} Feedback: #{feedback_name}", email.subject

    assert_includes email.body, feedback_text

    assert_includes email.body, "#{feedback_name} <#{feedback_email}>"
    # citation
    assert_includes email.body, "Mechanisms of changes in glucose metabolism and bodyweight"
    assert_includes email.body, "Madsbad"
    assert_includes email.body, "The Lancet Diabetes & Endocrinology"
    assert_includes email.body, "Published: 2014  Vol: 2  Iss: 2  p. 152"
    assert_includes email.body, "ISSN: 22138587"
    assert_includes email.body, "10.1016/S2213-8587(13)70218-3" # doi

    assert_includes email.body, "Original Source: #{umlaut_request.referrer_id}"

    # Permalink properly generated and included
    assert_present umlaut_request.referent.permalinks
    assert_includes email.body, "Permalink: http"
  end

  test "feedback with no umlaut_request" do
    feedback_name  = "Joe Example"
    feedback_email = "joe@example.org"
    feedback_text = "This is my feedback, yes it is"

    email = FeedbackMailer.feedback(@host, @to_email, :name => feedback_name, :email => feedback_email, :feedback => feedback_text).deliver
    # just no raise is good enough for this test for now, mostly

    assert_includes email.body, "No citation supplied"
  end

end