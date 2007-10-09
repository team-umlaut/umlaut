require 'test_helper'

class ListMetadataFormatsTest < Test::Unit::TestCase
  def test_list
    client = OAI::Client.new 'http://localhost:3333/oai' 
    response = client.list_metadata_formats
    assert_kind_of OAI::ListMetadataFormatsResponse, response
    assert response.entries.size > 0

    format = response.entries[0]
    assert_kind_of OAI::MetadataFormat, format
    assert_equal 'oai_dc', format.prefix
    assert_equal 'http://www.openarchives.org/OAI/2.0/oai_dc.xsd', format.schema
    assert_equal 'http://www.openarchives.org/OAI/2.0/oai_dc/', format.namespace
  end
  
end

