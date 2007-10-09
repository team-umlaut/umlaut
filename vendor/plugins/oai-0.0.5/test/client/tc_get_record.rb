require 'test_helper'

class GetRecordTest < Test::Unit::TestCase
  
  def test_get_one
    client = OAI::Client.new 'http://localhost:3333/oai'
    response = client.get_record :identifier => 'oai:test/3'
    assert_kind_of OAI::GetRecordResponse, response
    assert_kind_of OAI::Record, response.record
    assert_kind_of REXML::Element, response.record.metadata
    assert_kind_of OAI::Header, response.record.header

    # minimal check that the header is working
    assert_equal 'oai:test/3', 
      response.record.header.identifier

    # minimal check that the metadata is working
    #assert 'en', response.record.metadata.elements['.//dc:language'].text
  end

  def test_missing_identifier
    client = OAI::Client.new 'http://localhost:3333/oai'
    begin
      client.get_record :metadata_prefix => 'oai_dc'
      flunk 'invalid get_record did not throw OAI::Exception'
    rescue OAI::Exception => e
      assert_match /The request includes illegal arguments/, e.to_s
    end
  end

  def test_deleted_record
    client = OAI::Client.new 'http://localhost:3333/oai'
    record = client.get_record :identifier => 'oai:test/275' 
    assert record.deleted?
  end

end
