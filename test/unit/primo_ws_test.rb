require 'test_helper'

class PrimoWSTest < ActiveSupport::TestCase
  PNX_NS = {'pnx' => 'http://www.exlibrisgroup.com/xsd/primo/primo_nm_bib'}
  SEARCH_NS = {'search' => 'http://www.exlibrisgroup.com/xsd/jaguar/search'}
  
  def setup
    @primo_definition = YAML.load( %{
        type: PrimoService
        priority: 2 # After SFX, to get SFX metadata enhancement
        status: active
        base_url: http://bobcat.library.nyu.edu
        vid: NYU
        institution: NYU
        holding_search_institution: NYU
        holding_search_text: Search for this title in BobCat.
        suppress_holdings: [ !ruby/regexp '/\$\$LBWEB/', !ruby/regexp '/\$\$LNWEB/', !ruby/regexp '/\$\$LTWEB/', !ruby/regexp '/\$\$LWEB/', !ruby/regexp '/\$\$1Restricted Internet Resources/' ]
        ez_proxy: !ruby/regexp '/https\:\/\/ezproxy\.library\.nyu\.edu\/login\?url=/'
        service_types:
          - primo_source
          - holding_search
          - fulltext
          - table_of_contents
          - referent_enhance
          - cover_image
      })
    
    @base_url = @primo_definition["base_url"]
    @bogus_404_url = "http://library.nyu.edu/bogus"
    @bogus_200_url = "http://library.nyu.edu"
    @primo_test_doc_id = "nyu_aleph000062856"
    @primo_invalid_doc_id = "thisIsNotAValidDocId"
    @primo_test_problem_doc_id = "nyu_aleph000509288"
    @isbn_search_params = {:isbn => "0143039008"}
    @issn_search_params = {:issn => "0090-5720"}
    @title_search_params = {:title => "Travels with My Aunt"}
    @author_search_params = {:author => "Graham Greene"}
    @title_author_genre_search_params = {:title => "Travels with My Aunt", :author => "Graham Greene", :genre => "Book"}
  end
  
  # def test_primo_ws_benchmarks
  #   Benchmark.bmbm do |results|
  #     results.report("PrimoWS::Get Record:") { 
  #       (1..10).each {
  #         get_record = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @base_url) 
  #       }
  #     }
  #     results.report("PrimoWS::SearchBrief by ISBN:") { 
  #       (1..10).each {
  #         get_record = Exlibris::PrimoWS::SearchBrief.new(@isbn_search_params, @base_url)
  #       }
  #     }
  #     results.report("PrimoWS::SearchBrief by title:") { 
  #       (1..10).each {
  #         get_record = Exlibris::PrimoWS::SearchBrief.new(@title_search_params, @base_url)
  #       }
  #     }
  #   end
  # end

  def test_bogus_response
    skip("Won't work outside NYU.");
    assert_raise(SOAP::HTTPStreamError) {
      ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @bogus_404_url)
    }
    assert_raise(SOAP::HTTPStreamError) {
      ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @bogus_200_url)
    }
  end
  
  # Test GetRecord for a single Primo document.
  def test_get_record
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Nokogiri::XML::Document, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
    assert_equal(@primo_test_doc_id, ws.response.at("//pnx:control/pnx:recordid", PNX_NS).inner_text, "#{ws.class} returned an unexpected record: #{ws.response.to_xml(:indent => 5, :encoding => 'UTF-8')}")
  end
  
  def test_count_get_record
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @base_url)
    assert_equal("1", ws.response.at("//search:DOCSET", SEARCH_NS)["TOTALHITS"])
  end
  
  def test_count_search_brief
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::SearchBrief.new(@isbn_search_params, @base_url)
    assert_equal("1", ws.response.at("//search:DOCSET", SEARCH_NS)["TOTALHITS"])
  end
  
  def test_get_genre_discrepancy
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_problem_doc_id, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Nokogiri::XML::Document, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
    assert_equal(@primo_test_problem_doc_id, ws.response.at("//pnx:control/pnx:recordid", PNX_NS).inner_text, "#{ws.class} returned an unexpected record: #{ws.response.to_xml(:indent => 5, :encoding => 'UTF-8')}")
    assert_not_nil(ws.response.at("//pnx:display/pnx:availlibrary", PNX_NS).inner_text, "#{ws.class} returned an unexpected record: #{ws.response.to_xml(:indent => 5, :encoding => 'UTF-8')}")
  end
  
  # Test GetRecord with invalid Primo doc id.
  def test_get_bogus_record
    skip("Won't work outside NYU.");
    assert_raise(RuntimeError) {
      ws = Exlibris::PrimoWS::GetRecord.new(@primo_invalid_doc_id, @base_url)
    }
  end
  
  # Test SearchBrief by isbn.
  def test_isbn_search
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::SearchBrief.new(@isbn_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Nokogiri::XML::Document, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end
  
  # Test SearchBrief by issn.
  def test_issn_search
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::SearchBrief.new(@issn_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Nokogiri::XML::Document, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end
  
  # Test SearchBrief by title.
  def test_title_search
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::SearchBrief.new(@title_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Nokogiri::XML::Document, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end
  
  # Test SearchBrief by author.
  def test_author_search
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::SearchBrief.new(@author_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Nokogiri::XML::Document, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end
  
  # Test SearchBrief by title/author/genre.
  def test_title_author_genre_search
    skip("Won't work outside NYU.");
    ws = Exlibris::PrimoWS::SearchBrief.new(@title_author_genre_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Nokogiri::XML::Document, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end 
end