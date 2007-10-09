require 'test_helper'

class ExceptionTest < Test::Unit::TestCase

  def test_http_error
    client = OAI::Client.new 'http://www.example.com'
    assert_raises(OAI::Exception) { client.identify }
  end

  def test_xml_error
    client = OAI::Client.new 'http://www.yahoo.com'
    begin 
      client.identify
    rescue OAI::Exception => e
      assert_match /response not well formed XML/, e.to_s, 'xml error'
    end
  end

  def test_oai_error
    client = OAI::Client.new 'http://localhost:3333/oai'
    assert_raises(OAI::Exception) do
      client.list_identifiers :resumption_token => 'bogus'
    end
  end

  # must pass in options as a hash 
  def test_parameter_error
    client = OAI::Client.new 'http://localhost:3333/oai'
    assert_raises(OAI::ArgumentException) {client.get_record('foo')}
    assert_raises(OAI::ArgumentException) {client.list_identifiers('foo')}
    assert_raises(OAI::ArgumentException) {client.list_records('foo')}
    assert_raises(OAI::ArgumentException) {client.list_metadata_formats('foo')}
    assert_raises(OAI::ArgumentException) {client.list_sets('foo')}
  end
  
end
