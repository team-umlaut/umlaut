require 'test_helper'

class SimpleResumptionProviderTest < Test::Unit::TestCase
  include REXML
  
  def test_full_harvest
    doc = Document.new(@provider.list_records)
    assert_not_nil doc.elements["/OAI-PMH/resumptionToken"]
    assert_equal 25, doc.elements["/OAI-PMH/ListRecords"].to_a.size
    token = doc.elements["/OAI-PMH/resumptionToken"].text
    doc = Document.new(@provider.list_records(:resumption_token => token))
    assert_not_nil doc.elements["/OAI-PMH/resumptionToken"]
    token = doc.elements["/OAI-PMH/resumptionToken"].text
    assert_equal 25, doc.elements["/OAI-PMH/ListRecords"].to_a.size
    doc = Document.new(@provider.list_records(:resumption_token => token))
    assert_not_nil doc.elements["/OAI-PMH/resumptionToken"]
    token = doc.elements["/OAI-PMH/resumptionToken"].text
    assert_equal 25, doc.elements["/OAI-PMH/ListRecords"].to_a.size
    doc = Document.new(@provider.list_records(:resumption_token => token))
    assert_nil doc.elements["/OAI-PMH/resumptionToken"]
    assert_equal 25, doc.elements["/OAI-PMH/ListRecords"].to_a.size
  end
  
  def test_from_and_until
    DCField.update_all(['updated_at = ?', Chronic.parse("September 15 2005")],
      "id < 26")
    DCField.update_all(['updated_at = ?', Chronic.parse("November 1 2005")],
      "id < 51 and id > 25")
    
    total = DCField.count(:id, :conditions => ["updated_at >= ? AND updated_at <= ?", Chronic.parse("September 1 2005"), Chronic.parse("November 30 2005")])

    # Should return 50 records broken into 2 groups of 25.
    doc = Document.new(
      @provider.list_records(
        :from => Chronic.parse("September 1 2005"),
        :until => Chronic.parse("November 30 2005"))
      )
    assert_equal total/2, doc.elements["/OAI-PMH/ListRecords"].to_a.size
    assert_not_nil doc.elements["/OAI-PMH/resumptionToken"]
    token = doc.elements["/OAI-PMH/resumptionToken"].text
    doc = Document.new(@provider.list_records(:resumption_token => token))
    assert_equal total/2, doc.elements["/OAI-PMH/ListRecords"].to_a.size
    assert_nil doc.elements["/OAI-PMH/resumptionToken"]
  end

  def setup
    @provider = SimpleResumptionProvider.new
    ARLoader.load
  end
  
  def teardown
    ARLoader.unload
  end
  
end
