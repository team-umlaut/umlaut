require 'test_helper'

class ResumptionTokenTest < Test::Unit::TestCase
  include REXML
  include OAI::Provider
  
  def setup
    @token = ResumptionToken.new(
      :from => Chronic.parse("January 1 2005"),
      :until => Chronic.parse("January 31 2005"), 
      :set => "A",
      :metadata_prefix => "oai_dc", 
      :last => 1
    )
  end

  def test_resumption_token_options_encoding
    assert_equal "oai_dc.s(A).f(2005-01-01T17:00:00Z).u(2005-01-31T17:00:00Z)",
      @token.to_s
  end
  
  def test_resumption_token_next_method
    assert_equal 100, @token.next(100).last
  end
  
  def test_resumption_token_to_condition_hash
    hash = @token.to_conditions_hash
    assert_equal @token.from, hash[:from]
    assert_equal @token.until, hash[:until]
    assert_equal @token.set, hash[:set]
    assert_equal @token.prefix, hash[:metadata_prefix]
  end

  def test_resumption_token_parsing
    new_token = ResumptionToken.parse(
      "oai_dc.s(A).f(2005-01-01T17:00:00Z).u(2005-01-31T17:00:00Z):1"
    )
    assert_equal @token, new_token
  end
  
  def test_resumption_token_to_xml
    doc = REXML::Document.new(@token.to_xml)
    assert_equal "#{@token.to_s}:#{@token.last}", doc.elements['/resumptionToken'].text
  end
    
end