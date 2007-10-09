require 'test_helper'

class OaiTest < Test::Unit::TestCase

  def setup
    @mapped_provider = MappedProvider.new
    @big_provider = BigProvider.new
  end
  
  def test_list_identifiers_for_correct_xml
    doc = REXML::Document.new(@mapped_provider.list_identifiers)
    assert_not_nil doc.elements['OAI-PMH/ListIdentifiers']
    assert_not_nil doc.elements['OAI-PMH/ListIdentifiers/header']
    assert_not_nil doc.elements['OAI-PMH/ListIdentifiers/header/identifier']
    assert_not_nil doc.elements['OAI-PMH/ListIdentifiers/header/datestamp']
    assert_not_nil doc.elements['OAI-PMH/ListIdentifiers/header/setSpec']
  end
  
  def test_list_records_for_correct_xml
    doc = REXML::Document.new(@mapped_provider.list_records)
    assert_not_nil doc.elements['OAI-PMH/ListRecords/record/header']
    assert_not_nil doc.elements['OAI-PMH/ListRecords/record/metadata']
  end
  
  def test_mapped_source
    assert_nothing_raised { REXML::Document.new(@mapped_provider.list_records) }
    doc = REXML::Document.new(@mapped_provider.list_records)
    assert_equal "title_0", doc.elements['OAI-PMH/ListRecords/record/metadata/oai_dc:dc/dc:creator'].text
    assert_equal "creator_0", doc.elements['OAI-PMH/ListRecords/record/metadata/oai_dc:dc/dc:title'].text
    assert_equal "tag_0", doc.elements['OAI-PMH/ListRecords/record/metadata/oai_dc:dc/dc:subject'].text
  end
  
  def test_from
    assert_nothing_raised { REXML::Document.new(@big_provider.list_records) }
    doc = REXML::Document.new(
      @big_provider.list_records(:from => Chronic.parse("February 1 2001"))
      )
    assert_equal 100, doc.elements['OAI-PMH/ListRecords'].to_a.size

    doc = REXML::Document.new(
      @big_provider.list_records(:from => Chronic.parse("January 1 2001"))
      )
    assert_equal 200, doc.elements['OAI-PMH/ListRecords'].to_a.size
  end
  
  def test_until
    assert_nothing_raised { REXML::Document.new(@big_provider.list_records) }
    doc = REXML::Document.new(
      @big_provider.list_records(:until => Chronic.parse("November 1 2000"))
      )
    assert_equal 100, doc.elements['OAI-PMH/ListRecords'].to_a.size
  end
  
  def test_from_and_until
    assert_nothing_raised { REXML::Document.new(@big_provider.list_records) }
    doc = REXML::Document.new(
      @big_provider.list_records(:from => Chronic.parse("November 1 2000"),
        :until => Chronic.parse("November 30 2000"))
      )
    assert_equal 100, doc.elements['OAI-PMH/ListRecords'].to_a.size

    doc = REXML::Document.new(
      @big_provider.list_records(:from => Chronic.parse("December 1 2000"),
      :until => Chronic.parse("December 31 2000"))
      )
    assert_equal 100, doc.elements['OAI-PMH/ListRecords'].to_a.size
  end
        
end
