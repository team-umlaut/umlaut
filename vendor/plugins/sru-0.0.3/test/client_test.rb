class ClientTests < Test::Unit::TestCase

  def test_explain
    client = SRU::Client.new 'http://z3950.loc.gov:7090/voyager'
    explain = client.explain
    assert_equal SRU::ExplainResponse, explain.class
    assert_equal '1.1', explain.version
    assert_equal 'z3950.loc.gov', explain.host
    assert_equal 7090, explain.port
    assert_equal 'voyager', explain.database
    assert_equal 'host=z3950.loc.gov port=7090 database=voyager version=1.1',
      explain.to_s
  end

  def test_search_retrieve
    client = SRU::Client.new 'http://z3950.loc.gov:7090/voyager'
    results = client.search_retrieve 'twain', :maximumRecords => 5
    assert_equal 5, results.entries.size
    assert results.number_of_records > 2000
    assert_equal REXML::Element, results.entries[0].class
    assert_equal 'record', results.entries[0].name

    # hopefully there isn't a document that matches this :)
    results = client.search_retrieve 'fidkidkdiejfl'
    assert_equal 0, results.entries.size
  end

  def test_default_maximum_records
    client = SRU::Client.new 'http://z3950.loc.gov:7090/voyager'
    results = client.search_retrieve 'twain'
    assert_equal 10, results.entries.size
  end

  # need to find a target that supports scan so we can exercise it
  #def test_scan
  #  # this scan response appears to be canned might need to change
  #  client = SRU::Client.new 'http://tweed.lib.ed.ac.uk:8080/elf/search/copac'
  #  scan = client.scan('foobar')
  #  assert scan.entries.size > 0
  #  assert_equal SRU::Term, scan.entries[0].class
  #  assert_equal 'low', scan.entries[0].value
  #  assert_equal '1', scan.entries[0].number_of_records
  #end

  def test_xml_exception
    assert_raise(SRU::Exception) {SRU::Client.new 'http://www.google.com'}
  end

  def test_http_exception
    assert_raise(SRU::Exception) {SRU::Client.new 'http://example.com'}
  end

end


