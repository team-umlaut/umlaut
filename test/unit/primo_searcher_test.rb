require "benchmark"

require File.dirname(__FILE__) + '/../test_helper'
class PrimoSearcherTest < ActiveSupport::TestCase
  def setup
    ServiceList.yaml_path =  RAILS_ROOT+"/lib/generators/umlaut_local/templates/services.yml-dist"
    @primo_definition = ServiceList.instance.definition("NYU_Primo")
    @base_url = @primo_definition["base_url"]
    @vid = @primo_definition["vid"]
    @primo_holdings_doc_id = "nyu_aleph000062856"
    @primo_rsrcs_doc_id = "nyu_aleph002895625"
    @primo_tocs_doc_id = "nyu_aleph003149772"
    @primo_dedupmrg_doc_id = "dedupmrg41684735"
    @primo_test_checked_out_doc_id = "nyu_aleph000089771"
    @primo_test_offsite_doc_id = "nyu_aleph002169696"
    @primo_test_ill_doc_id = "nyu_aleph001502625"
    @primo_test_diacritics1_doc_id = "nyu_aleph002975583"
    @primo_test_diacritics2_doc_id = "nyu_aleph003205339"
    @primo_test_diacritics3_doc_id = "nyu_aleph003365921"
    @primo_test_journals1_doc_id = "nyu_aleph002895625"
    @primo_invalid_doc_id = "thisIsNotAValidDocId"
    @primo_test_isbn = "0143039008"
    @primo_test_title = "Travels with My Aunt"
    @primo_test_author = "Graham Greene"
    @primo_test_genre = "Book"
    @primo_config = YAML.load_file("#{RAILS_ROOT}/config/umlaut_config/primo.yml")
    @searcher_setup = {
      :base_url => @base_url,
      :vid => @vid,
      :config => @primo_config
    }
    aleph_helper = Exlibris::Aleph::Config::Helper.instance()
  end
  
  def test_primo_searcher_benchmarks
    Benchmark.bmbm do |results|
      results.report("Primo Searcher:") {
        (1..10).each {
          searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_holdings_doc_id})
        }
      }
      searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_holdings_doc_id})
      results.report("Searcher#process_record") {
        (1..10).each {
          searcher.send(:process_record)
        }
      }
      results.report("Searcher#process_search_results") {
        (1..10).each {
          searcher.send(:process_search_results)
        }
      }
    end
  end

  # Test search for a single Primo document.
  def test_search_by_doc_id
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_holdings_doc_id})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Hpricot::Doc, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    assert_equal(@primo_holdings_doc_id, search_results.at("//control/recordid").inner_text, "#{searcher.class} returned an unexpected record: #{search_results.to_original_html}")
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for doc id: #{@primo_holdings_doc_id}.")
  end

  # Test search for an invalid Primo document.
  def test_search_by_invalid_doc_id
    assert_raise(RuntimeError) { 
      searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_invalid_doc_id})
    }
  end
  
  # Test invalid setup.
  def test_search_by_invalid_setup1
    assert_raise(RuntimeError) {
      searcher = Exlibris::Primo::Searcher.new({}, {:primo_id => @primo_invalid_doc_id})
    }
  end
  
  # Test invalid setup.
  def test_search_by_invalid_setup2
    assert_raise(RuntimeError) {
      searcher = Exlibris::Primo::Searcher.new({:base_url => @base_url, :config => nil}, {:primo_id => @primo_invalid_doc_id})
    }
  end
  
  # Test base setup search for a single Primo document.
  def test_search_base_setup_record_id
    searcher = Exlibris::Primo::Searcher.new({:base_url => @base_url}, {:primo_id => @primo_holdings_doc_id})
    holdings = searcher.holdings
    assert_instance_of(Array, holdings, "#{searcher.class} holdings is an unexpected object: #{holdings.class}")
    assert(holdings.count > 0, "#{searcher.class} returned 0 holdings for doc id: #{@primo_holdings_doc_id}.")
    first_holding = holdings.first
    assert_instance_of(Exlibris::Primo::Holding, first_holding, "#{searcher.class} first holding is an unexpected object: #{first_holding.class}")
    assert_equal("check_holdings", first_holding.status, "#{searcher.class} first holding has an unexpected status: #{first_holding.status}")
    assert_equal("NYU", first_holding.institution, "#{searcher.class} first holding has an unexpected institution: #{first_holding.institution}")
    assert_equal("BOBST", first_holding.library, "#{searcher.class} first holding has an unexpected library: #{first_holding.library}")
    assert_equal("Main Collection", first_holding.collection, "#{searcher.class} first holding has an unexpected collection: #{first_holding.collection}")
    assert_equal("(PR6013.R44 T7 2004 )", first_holding.call_number, "#{searcher.class} first holding has an unexpected call number: #{first_holding.call_number}")
  end
  
  # Test search by isbn.
  def test_search_by_isbn
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:isbn => @primo_test_isbn})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Hpricot::Doc, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    search_results.search("//search/isbn") do |isbn|
      assert_not_nil(isbn.inner_text.match(@primo_test_isbn), "#{searcher.class} returned an unexpected record: #{search_results.to_original_html}")
    end
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for ISBN: #{@primo_test_isbn}.")
  end
  
  # Test search by title/author/genre.
  def test_search_by_title_author_genre
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:title => @primo_test_title, :author => @primo_test_author, :genre => @primo_test_genre})
    assert_not_nil(searcher, "#{searcher.class} returned nil when instantiated.")
    search_results = searcher.response
    assert_instance_of(Hpricot::Doc, search_results, "#{searcher.class} search result is an unexpected object: #{search_results.class}")
    search_results.search("//search/title") do |title|
      assert_not_nil(title.inner_text.downcase.match(@primo_test_title.downcase), "#{searcher.class} returned an unexpected record: #{search_results.to_original_html}")
    end
    assert(searcher.count.to_i > 0, "#{searcher.class} returned 0 results for Title: #{@primo_test_title}.")
  end
  
  # Test search for a single Primo document w/ holdings.
  def test_holdings
    searcher = Exlibris::Primo::Searcher.new(@searcher_setup, {:primo_id => @primo_holdings_doc_id})
    holdings = searcher.holdings
    assert_instance_of(Array, holdings, 
      "#{searcher.class} holdings is an unexpected object: #{holdings.class}")
    assert_equal(1, holdings.count, 
      "#{searcher.class} returned 0 holdings for doc id: #{@primo_holdings_doc_id}.")
    first_holding = holdings.first
    assert_instance_of(
      Exlibris::Primo::Holding, 
      first_holding, 
      "#{searcher.class} first holding is an unexpected object: #{first_holding.class}")
    test_data = { 
      :record_id => "nyu_aleph000062856", 
      :source_id => "nyu_aleph", 
      :original_source_id => "NYU01", 
      :source_record_id => "000062856",
      :institution_code => "NYU", 
      :institution => "NYU", 
      :library_code => "BOBST",
      :library => "NYU Bobst",
      :status_code => "check_holdings", 
      :status => "Check Availability", 
      :id_one => "Main Collection", 
      :id_two => "(PR6013.R44 T7 2004 )", 
      :collection => "Main Collection", 
      :call_number => "(PR6013.R44 T7 2004 )", 
      :origin => nil, 
      :display_type => "book", 
      :coverage => [], 
      :notes => "",
      :url => "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=nyu_aleph000062856&institution=NYU&vid=#{@vid}", 
      :request_url => nil, 
      :match_reliability => ServiceResponse::MatchExact, 
      :request_link_supports_ajax_call => false }
    test_data.each { |key, value|
      assert_equal(
        value, 
        first_holding.send(key), 
        "#{searcher.class} first holding has an unexpected #{key}: #{first_holding.send(key)}")
    }
  end


  # Test search for a single Primo document w/ rsrcs.
  def test_rsrcs
    searcher = Exlibris::Primo::Searcher.new(
      @searcher_setup, 
      { :primo_id => @primo_rsrcs_doc_id })
    rsrcs = searcher.rsrcs
    assert_instance_of(Array, rsrcs,
      "#{searcher.class} rsrcs is an unexpected object: #{rsrcs.class}")
    assert_equal(2, rsrcs.count,
      "#{searcher.class} returned an unexpected amount of rsrcs (#{rsrcs.count}) for doc id: #{@primo_rsrcs_doc_id}.")
    first_rsrc = rsrcs.first
    assert_instance_of(
      Exlibris::Primo::Rsrc, 
      first_rsrc,
      "#{searcher.class} first rsrc is an unexpected object: #{first_rsrc.class}")
    test_data = { 
      :record_id => "nyu_aleph002895625", 
      :v => nil, 
      :url => "http://ezproxy.library.nyu.edu:2048/login?url=http://mq.oxfordjournals.org/",
      :display => "Online Version",
      :institution_code => "NYU", 
      :origin => nil, 
      :notes => "" }
    test_data.each { |key, value|
      assert_equal(
        value, 
        first_rsrc.send(key), 
        "#{searcher.class} first rsrc has an unexpected #{key}: #{first_rsrc.send(key)}")
    }
  end

  # Test search for a single Primo document w/ tocs.
  def test_tocs
    searcher = Exlibris::Primo::Searcher.new(
      @searcher_setup, 
      { :primo_id => @primo_tocs_doc_id })
    tocs = searcher.tocs
    assert_instance_of(Array, tocs,
      "#{searcher.class} tocs is an unexpected object: #{tocs.class}")
    assert_equal(1, tocs.count,
      "#{searcher.class} returned an unexpected amount of tocs (#{tocs.count}) for doc id: #{@primo_tocs_doc_id}.")
    first_toc = tocs.last
    assert_instance_of(
      Exlibris::Primo::Toc, 
      first_toc, 
      "#{searcher.class} first toc is an unexpected object: #{first_toc.class}")
  test_data = { 
    :record_id => "nyu_aleph003149772", 
    :url => "http://www.loc.gov/catdir/toc/onix07/2001024342.html",
    :display => "Table of Contents",
    :notes => "" }
  test_data.each { |key, value|
    assert_equal(
      value, 
      first_toc.send(key), 
      "#{searcher.class} first toc has an unexpected #{key}: #{first_toc.send(key)}")
  }
  end
  
  def test_dedupmrg
      searcher = Exlibris::Primo::Searcher.new(
        @searcher_setup, 
        { :primo_id => @primo_dedupmrg_doc_id })
      holdings = searcher.holdings
      assert_instance_of(Array, holdings, 
        "#{searcher.class} holdings is an unexpected object: #{holdings.class}")
      assert_equal(2, holdings.count, 
        "#{searcher.class} returned 0 holdings for doc id: #{@primo_holdings_doc_id}.")
      first_holding = holdings.first
      assert_instance_of(
        Exlibris::Primo::Holding, 
        first_holding, 
        "#{searcher.class} first holding is an unexpected object: #{first_holding.class}")
      test_data = { 
        :record_id => "dedupmrg41684735", 
        :source_id => "nyu_aleph", 
        :original_source_id => "NYU01", 
        :source_record_id => "002736245",
        :institution_code => "NYU", 
        :institution => "NYU", 
        :library_code => "BOBST",
        :library => "NYU Bobst",
        :status_code => "check_holdings", 
        :status => "Check Availability", 
        :id_one => "Main Collection", 
        :id_two => "(HB1 .J55 )", 
        :collection => "Main Collection", 
        :call_number => "(HB1 .J55 )", 
        :origin => "nyu_aleph002736245", 
        :display_type => "journal", 
        :coverage => [], 
        :notes => "",
        :url => "#{@base_url}/primo_library/libweb/action/dlDisplay.do?docId=dedupmrg41684735&institution=NYU&vid=#{@vid}", 
        :request_url => nil, 
        :match_reliability => ServiceResponse::MatchExact, 
        :request_link_supports_ajax_call => false }
      test_data.each { |key, value|
        assert_equal(
          value, 
          first_holding.send(key), 
          "#{searcher.class} first holding has an unexpected #{key}: #{first_holding.send(key)}")
      }
      rsrcs = searcher.rsrcs
      assert_instance_of(Array, rsrcs,
        "#{searcher.class} rsrcs is an unexpected object: #{rsrcs.class}")
      assert_equal(2, rsrcs.count,
        "#{searcher.class} returned an unexpected amount of rsrcs (#{rsrcs.count}) for doc id: #{@primo_rsrcs_doc_id}.")
      first_rsrc = rsrcs.first
      assert_instance_of(
        Exlibris::Primo::Rsrc, 
        first_rsrc,
        "#{searcher.class} first rsrc is an unexpected object: #{first_rsrc.class}")
      test_data = { 
        :record_id => "dedupmrg41684735", 
        :v => "", 
        :url => "https://ezproxy.library.nyu.edu/login?url=http://www.sciencedirect.com/science/journal/00905720",
        :display => "Online Version",
        :institution_code => "NYU", 
        :origin => "nyu_aleph002736245", 
        :notes => "" }
      test_data.each { |key, value|
        assert_equal(
          value, 
          first_rsrc.send(key), 
          "#{searcher.class} first rsrc has an unexpected #{key}: #{first_rsrc.send(key)}")
      }
  end

  def test_holdings_diacritics1
    searcher = Exlibris::Primo::Searcher.new(
      @searcher_setup, 
      { :primo_id => @primo_test_diacritics1_doc_id })
    assert_equal(
      "Rubāʻīyāt-i Bābā Ṭāhir", 
      searcher.btitle, 
      "#{searcher.class} has an unexpected btitle: #{searcher.btitle}")
    assert_equal(
      "Bābā-Ṭāhir, 11th cent", 
      searcher.au, 
      "#{searcher.class} has an unexpected author: #{searcher.au}")
  end
  
  # This test fails but I don't know why!
  def test_holdings_diacritics2
    searcher = Exlibris::Primo::Searcher.new(
      @searcher_setup, 
      { :primo_id => @primo_test_diacritics2_doc_id })
    assert_equal(
      "أقليم توات خلال القرنين الثامن عشر والتاسع عشر الميلاديين : دراسة لأوضاع الأقليم السياسية والأجتماعية والأقتصادية والثقافية، مع تحقيق كتاب القول البسيط في أخبار تمنطيط (لمحمد بن بابا حيده)", 
      searcher.btitle, 
      "#{searcher.class} has an unexpected btitle: #{searcher.btitle}")
    assert_equal(
      "Faraj, Faraj Maḥmūd", 
      searcher.au, 
      "#{searcher.class} has an unexpected author: #{searcher.au}")
    assert_equal("(DT299.T88 F373 2007)", first_holding.call_number, "#{searcher.class} first holding has an unexpected call number: #{first_holding.call_number}")
  end
  
  # Record doesn't exist in BobCat dev
  # def test_holdings_diacritics3
  #   searcher = Exlibris::Primo::Searcher.new(
  #     @searcher_setup, 
  #     { :primo_id => @primo_test_diacritics3_doc_id })
  #   assert_equal(
  #     "Mul har ha-gaʻash : ḥoḳre toldot Yiśraʼel le-nokhaḥ ha-Shoʼah", 
  #     searcher.btitle, 
  #     "#{searcher.class} has an unexpected btitle: #{searcher.btitle}")
  #   assert_equal(
  #     "Engel, David", 
  #     searcher.au, 
  #     "#{searcher.class} has an unexpected author: #{searcher.au}")
  # end
end