require 'test_helper'
class AlephRecordTest < Test::Unit::TestCase
  
  nyu_only_tests(self.name) do
    
    def setup
      @primo_config = YAML.load_file("#{Rails.root}/config/primo.yml")
      @nyu_aleph_config = @primo_config["sources"]["nyu_aleph"]
      @rest_url = @nyu_aleph_config["rest_url"]
      @aleph_doc_library = "NYU01"
      @aleph_doc_number = "000062856"
      @bogus_url = "http://library.nyu.edu/bogus"
    end
  
    
    # Test exception handling for bogus response.
    def test_bogus_response
      aleph_record = Exlibris::Aleph::Record.new(@aleph_doc_library, @aleph_doc_number, @bogus_url)
      assert_raise(RuntimeError) { aleph_record.bib }
      assert_raise(RuntimeError) { aleph_record.holdings }
      assert_raise(MultiXml::ParseError) { aleph_record.items }
    end
  
    # Test search for a single Primo document.
    def test_record
      aleph_record = Exlibris::Aleph::Record.new(@aleph_doc_library, @aleph_doc_number, @rest_url)
      bib = aleph_record.bib
      assert_nil(aleph_record.error, "Failure in #{aleph_record.class} while calling bib: #{aleph_record.error}")
      holdings = aleph_record.holdings
      assert_nil(aleph_record.error, "Failure in #{aleph_record.class} while calling holdings: #{aleph_record.error}")
      items = aleph_record.items
      assert_nil(aleph_record.error, "Failure in #{aleph_record.class} while calling items: #{aleph_record.error}")
    end
  end
end