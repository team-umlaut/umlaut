require 'test_helper'

class IdentifyTest < Test::Unit::TestCase

  def test_ok
    client = OAI::Client.new 'http://localhost:3333/oai'
    response = client.identify
    assert_kind_of OAI::IdentifyResponse, response
    assert_equal 'Complex Provider [http://localhost]', response.to_s
    #assert_equal 'PubMed Central (PMC3 - NLM DTD) [http://www.pubmedcentral.gov/oai/oai.cgi]', response.to_s
  end

end
