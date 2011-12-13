require File.dirname(__FILE__) + '/../test_helper'
class AlephRecordBenchMarks < ActiveSupport::TestCase
  def setup
    @primo_config = YAML.load_file("#{Rails.root}/config/umlaut_config/primo.yml")
    @nyu_aleph_config = @primo_config["sources"]["nyu_aleph"]
    @rest_url = @nyu_aleph_config["rest_url"]
    @aleph_doc_library = "NYU01"
    @aleph_doc_number = "000062856"
    @bogus_url = "http://library.nyu.edu/bogus"
    @TESTS = 10
  end

  # Get benchmarks for calls to the Aleph API.
  def test_benchmarks
    # Display performance benchmarks.
    time = Benchmark.bmbm do |results|
      results.report("Aleph items:") { @TESTS.times { 
        aleph_record = Exlibris::Aleph::Record.new(@aleph_doc_library, @aleph_doc_number, @rest_url)
        items = aleph_record.items 
      } }    
      results.report("Aleph bib and holdings:") { @TESTS.times { 
        aleph_record = Exlibris::Aleph::Record.new(@aleph_doc_library, @aleph_doc_number, @rest_url)
        items = aleph_record.bib 
        items = aleph_record.holdings 
      } }    
    end
  end
end