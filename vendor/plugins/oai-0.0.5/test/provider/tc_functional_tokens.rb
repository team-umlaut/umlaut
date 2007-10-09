require 'test_helper'

class ResumptionTokenFunctionalTest < Test::Unit::TestCase
  include REXML
  
  def setup
    @provider = ComplexProvider.new
  end

  def test_resumption_tokens
    assert_nothing_raised { Document.new(@provider.list_records) }
    doc = Document.new(@provider.list_records)
    assert_not_nil doc.elements["/OAI-PMH/resumptionToken"]
    assert_equal 100, doc.elements["/OAI-PMH/ListRecords"].to_a.size
    token = doc.elements["/OAI-PMH/resumptionToken"].text
    doc = Document.new(@provider.list_records(:resumption_token => token))
    assert_not_nil doc.elements["/OAI-PMH/resumptionToken"]
    assert_equal 100, doc.elements["/OAI-PMH/ListRecords"].to_a.size
  end

  def test_from_and_until_with_resumption_tokens
    # Should return 300 records broken into 3 groups of 100.
    assert_nothing_raised { Document.new(@provider.list_records) }
    doc = Document.new(
      @provider.list_records(
        :from => Chronic.parse("September 1 2004"),
        :until => Chronic.parse("November 30 2004"))
      )
    assert_equal 100, doc.elements["/OAI-PMH/ListRecords"].to_a.size
    token = doc.elements["/OAI-PMH/resumptionToken"].text
  
    doc = Document.new(@provider.list_records(:resumption_token => token))
    assert_not_nil doc.elements["/OAI-PMH/resumptionToken"]
    assert_equal 100, doc.elements["/OAI-PMH/ListRecords"].to_a.size
    token = doc.elements["/OAI-PMH/resumptionToken"].text

    doc = Document.new(@provider.list_records(:resumption_token => token))
    assert_nil doc.elements["/OAI-PMH/resumptionToken"]
    assert_equal 100, doc.elements["/OAI-PMH/ListRecords"].to_a.size
  end
    
end