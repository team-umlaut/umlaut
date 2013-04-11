require 'test_helper'

# The default partial for testing holding section. 
#
# NOT fully tested, this is just a start. 
#
# Mocking up things to test a real request is worse than it should be
# in Umlaut, 10 year old code some places, sorry! 
class HoldingTest < ActionView::TestCase
	def setup
		# Not sure why ActionView::TestCase isn't initializing a rails request for us
		request ||= ActionController::TestRequest.new
		@user_request = Request.find_or_create({}, session, request)
	end

	def test_includes_holding_search
		holding_responses = [
			ServiceResponse.create_from_hash(:count => "10",
            :display_text => "10 possible matches in catalog", 
            :url => "http://catalog.example.org",
            :service_type_value => "holding_search",
            :service_id => "DummyService")
		]

		render "resolve/holding", :holding => holding_responses

		assert_select ".umlaut-holding-search"
		assert_select ".umlaut-unavailable", 0
	end
end