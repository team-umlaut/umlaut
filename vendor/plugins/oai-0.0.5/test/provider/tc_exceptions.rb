require 'test_helper'

class ProviderExceptions < Test::Unit::TestCase

  def setup
    @provider = ComplexProvider.new
  end

  def test_resumption_token_exception
    assert_raise(OAI::ResumptionTokenException) do
      @provider.list_records(:resumption_token => 'aaadddd:1000')
    end
    assert_raise(OAI::ResumptionTokenException) do
      @provider.list_records(:resumption_token => 'oai_dc:1000')
    end
    assert_raise(OAI::ResumptionTokenException) do
      @provider.list_identifiers(:resumption_token => '..::!:.:!:')
    end
    assert_raise(OAI::ResumptionTokenException) do
      @provider.list_identifiers(:resumption_token => '\:\\:\/$%^&*!@#!:1')
    end
  end
  
  def test_bad_verb_raises_exception
    assert @provider.process_request(:verb => 'BadVerb') =~ /badVerb/
    assert @provider.process_request(:verb => '\a$#^%!@') =~ /badVerb/
    assert @provider.process_request(:verb => 'identity') =~ /badVerb/
    assert @provider.process_request(:verb => '!!\\$\$\.+') =~ /badVerb/
  end
  
  def test_bad_format_raises_exception
    assert_raise(OAI::FormatException) do
      @provider.get_record(:identifier => 'oai:test/1', :metadata_prefix => 'html')
    end
  end
  
  def test_bad_id_raises_exception
    assert_raise(OAI::IdException) do
      @provider.get_record(:identifier => 'oai:test/5000')
    end
    assert_raise(OAI::IdException) do
      @provider.get_record(:identifier => 'oai:test/-1')
    end
    assert_raise(OAI::IdException) do
      @provider.get_record(:identifier => 'oai:test/one')
    end
    assert_raise(OAI::IdException) do
      @provider.get_record(:identifier => 'oai:test/\\$1\1!')
    end
  end
  
  def test_no_records_match_dates_that_are_out_of_range
    assert_raise(OAI::NoMatchException) do
      @provider.list_records(:from => Chronic.parse("November 2 2000"), 
                             :until => Chronic.parse("November 1 2000"))
    end
  end
  
  def test_no_records_match_bad_set
    assert_raise(OAI::NoMatchException) { @provider.list_records(:set => 'unknown') }
  end
  
end
