require File.dirname(__FILE__) + '/../test_helper'

class PrimoWSTest < ActiveSupport::TestCase
  
  def setup
    ServiceList.yaml_path =  RAILS_ROOT+"/lib/generators/umlaut_local/templates/services.yml-dist"
    @primo_definition = ServiceList.instance.definition("NYU_Primo")
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
  
  def test_primo_ws_benchmarks
    Benchmark.bmbm do |results|
      results.report("PrimoWS::Get Record:") { 
        (1..10).each {
          get_record = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @base_url) 
        }
      }
      results.report("PrimoWS::SearchBrief by ISBN:") { 
        (1..10).each {
          get_record = Exlibris::PrimoWS::SearchBrief.new(@isbn_search_params, @base_url)
        }
      }
      results.report("PrimoWS::SearchBrief by title:") { 
        (1..10).each {
          get_record = Exlibris::PrimoWS::SearchBrief.new(@title_search_params, @base_url)
        }
      }
    end
  end
  def test_bogus_response
    assert_raise(SOAP::HTTPStreamError) {
      ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @bogus_404_url)
    }
    assert_raise(SOAP::HTTPStreamError) {
      ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @bogus_200_url)
    }
  end
  
  # Test GetRecord for a single Primo document.
  def test_get_record
    ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_doc_id, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Hpricot::Doc, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
    assert_equal(@primo_test_doc_id, ws.response.at("//control/recordid").inner_text, "#{ws.class} returned an unexpected record: #{ws.response.to_original_html}")
  end
  
  def test_get_genre_discrepancy
    ws = Exlibris::PrimoWS::GetRecord.new(@primo_test_problem_doc_id, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Hpricot::Doc, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
    assert_equal(@primo_test_problem_doc_id, ws.response.at("//control/recordid").inner_text, "#{ws.class} returned an unexpected record: #{ws.response.to_original_html}")
    assert_not_nil(ws.response.at("//display/availlibrary").inner_text, "#{ws.class} returned an unexpected record: #{ws.response.to_original_html}")
  end
  
  # Test GetRecord with invalid Primo doc id.
  def test_get_bogus_record
    assert_raise(RuntimeError) {
      ws = Exlibris::PrimoWS::GetRecord.new(@primo_invalid_doc_id, @base_url)
    }
  end
  
  # Test SearchBrief by isbn.
  def test_isbn_search
    ws = Exlibris::PrimoWS::SearchBrief.new(@isbn_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Hpricot::Doc, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end
  
  # Test SearchBrief by issn.
  def test_issn_search
    ws = Exlibris::PrimoWS::SearchBrief.new(@issn_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Hpricot::Doc, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end
  
  # Test SearchBrief by title.
  def test_title_search
    ws = Exlibris::PrimoWS::SearchBrief.new(@title_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Hpricot::Doc, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end
  
  # Test SearchBrief by author.
  def test_author_search
    ws = Exlibris::PrimoWS::SearchBrief.new(@author_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Hpricot::Doc, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end
  
  # Test SearchBrief by title/author/genre.
  def test_title_author_genre_search
    ws = Exlibris::PrimoWS::SearchBrief.new(@title_author_genre_search_params, @base_url)
    assert_not_nil(ws, "#{ws.class} returned nil when instantiated.")
    assert_instance_of( Hpricot::Doc, ws.response, "#{ws.class} response is an unexpected object: #{ws.response.class}")
    assert_equal([], ws.error, "#{ws.class} encountered errors: #{ws.error}")
  end 
end