require 'test_helper'

class TestSimpleProvider < Test::Unit::TestCase

  def setup
    @simple_provider = SimpleProvider.new
    @model = @simple_provider.class.model
  end
  
  def test_identify
    doc = REXML::Document.new(@simple_provider.identify)
    assert_equal @simple_provider.class.name,
      doc.elements["/OAI-PMH/Identify/repositoryName"].text
    assert_equal SimpleModel.new.earliest.to_s,
      doc.elements["/OAI-PMH/Identify/earliestDatestamp"].text
  end

  def test_list_sets
    doc = REXML::Document.new(@simple_provider.list_sets)
    sets = doc.elements["/OAI-PMH/ListSets"]
    assert_equal @model.sets.size, sets.size
    assert_equal @model.sets[0].name, sets[0].elements["//setName"].text
  end
  
  def test_metadata_formats
    assert_nothing_raised { REXML::Document.new(@simple_provider.list_metadata_formats) }
    doc =  REXML::Document.new(@simple_provider.list_metadata_formats)
    assert_equal "oai_dc",
      doc.elements['/OAI-PMH/ListMetadataFormats/metadataFormat/metadataPrefix'].text
  end
  
  def test_list_records_without_constraints
    assert_nothing_raised { REXML::Document.new(@simple_provider.list_records) }

    total = @model.find(:all).size
    doc = REXML::Document.new(@simple_provider.list_records)
    assert_equal total, doc.elements['OAI-PMH/ListRecords'].size
  end
  
  def test_list_records_with_set_equal_a
    total = @model.find(:all, :set => 'A').size
    doc = REXML::Document.new(@simple_provider.list_records(:set => 'A'))
    assert_equal total, doc.elements['OAI-PMH/ListRecords'].size
  end
  
  def test_list_record_with_set_equal_ab
    total = @model.find(:all, :set => 'A:B').size
    doc = REXML::Document.new(@simple_provider.list_records(:set => 'A:B'))
    assert_equal total, doc.elements['OAI-PMH/ListRecords'].size
  end

  def test_list_identifiers_without_constraints
    assert_nothing_raised { REXML::Document.new(@simple_provider.list_identifiers) }

    total = @model.find(:all).size
    doc = REXML::Document.new(@simple_provider.list_identifiers)
    assert_equal total, doc.elements['OAI-PMH/ListIdentifiers'].to_a.size
  end
  
  def test_list_identifiers_with_set_equal_a
    total = @model.find(:all, :set => 'A').size
    doc = REXML::Document.new(@simple_provider.list_identifiers(:set => 'A'))
    assert_equal total, doc.elements['OAI-PMH/ListIdentifiers'].to_a.size
  end
  
  def test_list_indentifiers_with_set_equal_ab
    total = @model.find(:all, :set => 'A:B').size
    doc = REXML::Document.new(@simple_provider.list_identifiers(:set => 'A:B'))
    assert_equal total, doc.elements['OAI-PMH/ListIdentifiers'].to_a.size
  end

  def test_get_record
    assert_nothing_raised { REXML::Document.new(@simple_provider.get_record(:identifier => 'oai:test/1')) }
    doc = REXML::Document.new(@simple_provider.get_record(:identifier => 'oai:test/1'))
    assert_equal 'oai:test/1', doc.elements['OAI-PMH/GetRecord/record/header/identifier'].text
  end
  
  def test_deleted_record
    assert_nothing_raised { REXML::Document.new(@simple_provider.get_record(:identifier => 'oai:test/6')) }
    doc = REXML::Document.new(@simple_provider.get_record(:identifier => 'oai:test/5'))
    assert_equal 'oai:test/5', doc.elements['OAI-PMH/GetRecord/record/header/identifier'].text
    assert_equal 'deleted', doc.elements['OAI-PMH/GetRecord/record/header'].attributes["status"]
  end
          
end
