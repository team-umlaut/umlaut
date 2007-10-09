require 'test_helper'

class LibXMLTest < Test::Unit::TestCase

  def test_oai_exception
    return unless have_libxml

    uri = 'http://localhost:3333/oai'
    client = OAI::Client.new uri, :parser => 'libxml'
    assert_raises(OAI::Exception) {client.get_record(:identifier => 'nosuchid')}
  end

  def test_list_records
    return unless have_libxml

    # since there is regex magic going on to remove default oai namespaces 
    # it's worth trying a few different oai targets
    oai_targets = %w{
      http://localhost:3333/oai
    }

    #oai_targets = %w{
    #  http://etd.caltech.edu:80/ETD-db/OAI/oai
    #  http://ir.library.oregonstate.edu/dspace-oai/request
    #  http://memory.loc.gov/cgi-bin/oai2_0
    #  http://libeprints.open.ac.uk/perl/oai2
    #}


    oai_targets.each do |uri|
      client = OAI::Client.new uri, :parser => 'libxml'
      records = client.list_records
      records.each do |record|
        assert record.header.identifier
        next if record.deleted?
        assert_kind_of XML::Node, record.metadata
      end
    end
  end

  def test_deleted_record
    return unless have_libxml

    uri = 'http://localhost:3333/oai'
    client = OAI::Client.new(uri, :parser => 'libxml')
    response = client.get_record :identifier => 'oai:test/275'
    assert response.record.deleted?
  end
  
  private

  def have_libxml
    begin
      require 'xml/libxml'
      return true
    rescue LoadError
      return false
    end
  end

end
