require 'test_helper'

class GetRecordsTest < Test::Unit::TestCase
  def test_get_records
    client = OAI::Client.new 'http://localhost:3333/oai'
    response = client.list_records 
    assert_kind_of OAI::ListRecordsResponse, response
    assert response.entries.size > 0
    assert_kind_of OAI::Record,  response.entries[0]
  end
  
end
