require 'test_helper'

class ListIdentifiersTest < Test::Unit::TestCase

  def test_list_with_resumption_token
    client = OAI::Client.new 'http://localhost:3333/oai' 

    # get a list of identifier headers
    response = client.list_identifiers :metadata_prefix => 'oai_dc' 
    assert_kind_of OAI::ListIdentifiersResponse, response
    assert_kind_of OAI::Response, response
    assert response.entries.size > 0

    # make sure header is put together reasonably
    header = response.entries[0]
    assert_kind_of OAI::Header, header
    assert header.identifier
    assert header.datestamp
    assert header.set_spec

    # exercise a resumption token and make sure first identifier is different
    first_identifier = response.entries[0].identifier
    token = response.resumption_token
    assert_not_nil token
    response = client.list_identifiers :resumption_token => token
    assert response.entries.size > 0
    assert_not_equal response.entries[0].identifier, first_identifier
  end

  def test_list_with_date_range
    client = OAI::Client.new 'http://localhost:3333/oai'
    from_date = Date.new(1998,1,1)
    until_date  = Date.new(2002,1,1)
    response = client.list_identifiers :from => from_date, :until => until_date
    assert response.entries.size > 0
  end

  def test_list_with_datetime_range
    # xtcat should support higher granularity
    client = OAI::Client.new 'http://localhost:3333/oai'
    from_date = DateTime.new(2001,1,1)
    until_date = DateTime.now
    response = client.list_identifiers :from => from_date, :until => until_date
    assert response.entries.size > 0
  end

  def test_invalid_argument
    client = OAI::Client.new 'http://localhost:3333/oai'
    assert_raise(OAI::ArgumentException) {client.list_identifiers :foo => 'bar'}
  end
  
end
