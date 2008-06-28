# tests for google book search service
# Only the the simplest of tests are done so far. To do more advanced tests,
# request fixtures for more cases should be created.

$:.unshift File.join(File.dirname(__FILE__),'..','lib')
require File.dirname(__FILE__) + '/../test_helper'

require 'test/unit'
require 'rubygems'

require 'lib/service'
require 'lib/metadata_helper'
require 'lib/service_adaptors/google_book_search'

require 'yaml'

class GoogleBookSearchTest < Test::Unit::TestCase
  
  fixtures :requests, :referents, :referent_values
  
  
  def setup
    yaml_config = File.open('config/umlaut_distribution/services.yml-dist').read
    config_y = YAML.load(yaml_config)
    @config_default = config_y['GoogleBookSearch']
    @gbs_default = GoogleBookSearch.new(@config_default)
    @gbs_minimum = GoogleBookSearch.new({"priority"=>1})
    
    # Bunch of responses in the proper format somtimes followed by the hash that
    # will result. The values here are not necessarily true/real.
    # For instance the preview value is likely faked to test methods
    # Only those currently used are uncommented.
    @response_one = 'gbscallback({"ISBN:030905382X":{"bib_key":"ISBN:030905382X","info_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26printsec=frontcover\x26sig=9-7ypznOwL_rECoKJLizCBpodds\x26source=gbs_ViewAPI","thumbnail_url":"http://bks7.books.google.com/books?id=XiiYq5U1qEUC\x26pg=PP1\x26img=1\x26zoom=5\x26sig=2XmDi4HEhbqply9YjIsuopFQLAk","preview":"noview"}});'
    #@one_full_view = 'gbscallback({"ISBN:1582183392":{"bib_key":"ISBN:1582183392","info_url":"http://books.google.com/books?id=bFGPoGrAXbwC\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=bFGPoGrAXbwC\x26printsec=frontcover\x26sig=kYnPnuSmFdbm5rJfxNUN0_Qa3Zk\x26source=gbs_ViewAPI","thumbnail_url":"http://bks8.books.google.com/books?id=bFGPoGrAXbwC\x26pg=PP1\x26img=1\x26zoom=5\x26sig=bBu6nZ_q8k5uKZ43RrdBOElOCiA","preview":"full"}});'
    #@one_partial_view = 'gbscallback({"ISBN:9780618680009":{"bib_key":"ISBN:9780618680009","info_url":"http://books.google.com/books?id=yq1xDpicghkC\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=yq1xDpicghkC\x26printsec=frontcover\x26sig=wuZrXklCy_Duenlw3Ea0MTgIhYQ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks8.books.google.com/books?id=yq1xDpicghkC\x26pg=PP1\x26img=1\x26zoom=5\x26sig=3sezA1j1-qzTTtI5E8PTdHJDkHw","preview":"partial"}});'
    @response_three_duplicate_no_view = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"noview"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"noview"}});'
    @a_three_duplicate_no_view = [{
        "info_url"=>
          "http://books.google.com/books?id=E4R9AQAACAAJ&source=gbs_ViewAPI",
        "preview_url"=>
          "http://books.google.com/books?id=E4R9AQAACAAJ&source=gbs_ViewAPI",
        "preview"=>"noview",
        "bib_key"=>"ISBN:0393044548, OCLC:2985768, LCCN:76030648",
        "thumbnail_url"=>
          "http://bks3.books.google.com/books?id=E4R9AQAACAAJ&printsec=frontcover&img=1&zoom=5&sig=32ieZbDQYbQAeCNfW-vek8SfOxc"
      }]
   
    
    @data_frankenstein = [{"info_url"=>
          "http://books.google.com/books?id=92EbHgAACAAJ&source=gbs_ViewAPI",
        "preview_url"=>
          "http://books.google.com/books?id=92EbHgAACAAJ&source=gbs_ViewAPI",
        "preview"=>"noview",
        "bib_key"=>"ISBN:9780393964585, OCLC:33045872",
        "thumbnail_url"=>
          "http://bks3.books.google.com/books?id=92EbHgAACAAJ&printsec=frontcover&img=1&zoom=5&sig=ACfU3U10W3ycsrdiB-udzUYGnYtkVIp5tQ"}]
    
    #@one_fake_full_fake_partial = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"full"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"partial"}});'
    #@two_fake_full = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"full"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"full"}});'
    #@one_fake_full_one_fake_noview = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"full"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"noview"}});'
    #@one_fake_partial_one_fake_noview = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"partial"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"noview"}});'
    #@two_no_view_one_fake_partial = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"noview"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"partial"}});'
    #@two_full_one_fake_partial = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"full"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"full"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"partial"}});'
    #@one_partial_view = 'gbscallback({"ISBN:030905382X":{"bib_key":"ISBN:030905382X","info_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26printsec=frontcover\x26sig=9-7ypznOwL_rECoKJLizCBpodds\x26source=gbs_ViewAPI","thumbnail_url":"http://bks7.books.google.com/books?id=XiiYq5U1qEUC\x26pg=PP1\x26img=1\x26zoom=5\x26sig=2XmDi4HEhbqply9YjIsuopFQLAk","preview":"partial"}});'
    #@one_fake_noview = 'gbscallback({"ISBN:030905382X":{"bib_key":"ISBN:030905382X","info_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26printsec=frontcover\x26sig=9-7ypznOwL_rECoKJLizCBpodds\x26source=gbs_ViewAPI","thumbnail_url":"http://bks7.books.google.com/books?id=XiiYq5U1qEUC\x26pg=PP1\x26img=1\x26zoom=5\x26sig=2XmDi4HEhbqply9YjIsuopFQLAk","preview":"noview"}});'
  end
  
  def test_initialize_defaults
    gbs = GoogleBookSearch.new(@config_default)
    assert_equal('Google Book Search', gbs.display_name)
    #assert_equal('Google Book Search', gbs.display_text)
    assert_equal('GoogleBookSearch', gbs.name)   
    assert_equal(1, gbs.num_full_views)
    assert_equal(3, gbs.priority)
    assert_equal('active', gbs.status)
    assert_equal('standard', gbs.task)
    assert_equal(GoogleBookSearch, gbs.type)
    assert_equal('http://books.google.com/books?jscmd=viewapi&callback=gbscallback&bibkeys=', gbs.url)
  end
  
  def test_initialize_minimum
    gbs = GoogleBookSearch.new({"priority"=>1})
    assert_equal(1, gbs.priority)
    assert_equal('Google Book Search', gbs.display_name)
    assert_equal(1, gbs.num_full_views)
    assert_equal(1, gbs.priority)
    assert_equal('standard', gbs.task)
    assert_equal('http://books.google.com/books?jscmd=viewapi&callback=gbscallback&bibkeys=',
      gbs.url)
  end
  
  def test_get_bibkeys
    f = referents(:frankenstein)
    keys = @gbs_default.get_bibkeys(f)
    expected = CGI.escape('ISBN:9780393964585,OCLC:33045872')
    assert_equal(expected, keys)
  end
  
  # This doesn't check much of the response, but just enough to know we got
  # something back. The server for the thumbnail changes, so we can't do a 
  # simple match and a huge regexp was making my head hurt.
  def test_do_query
    response = @gbs_default.do_query('OCLC%3A02364071')
    expected = /gbscallback\(\{"OCLC:02364071":.*\}\);/
    assert_match(expected, response)
  end
  
  def test_clean_response    
    cleaned_response = @gbs_default.clean_response(@response_one)
    expected = '{"ISBN:030905382X":{"bib_key":"ISBN:030905382X","info_url":"http://books.google.com/books?id=XiiYq5U1qEUC&source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=XiiYq5U1qEUC&printsec=frontcover&sig=9-7ypznOwL_rECoKJLizCBpodds&source=gbs_ViewAPI","thumbnail_url":"http://bks7.books.google.com/books?id=XiiYq5U1qEUC&pg=PP1&img=1&zoom=5&sig=2XmDi4HEhbqply9YjIsuopFQLAk","preview":"noview"}}'
    assert_equal(expected, cleaned_response)
  end
  
  def test_parse_response_simple
    cleaned_response = @gbs_default.clean_response(@response_one)
    parsed_response = @gbs_default.parse_response(cleaned_response)
    expected_array_of_hash = [{
      "bib_key"=>"ISBN:030905382X",
      "info_url"=>
        "http://books.google.com/books?id=XiiYq5U1qEUC&source=gbs_ViewAPI",
      "preview_url"=>
        "http://books.google.com/books?id=XiiYq5U1qEUC&printsec=frontcover&sig=9-7ypznOwL_rECoKJLizCBpodds&source=gbs_ViewAPI",
      "thumbnail_url"=>
        "http://bks7.books.google.com/books?id=XiiYq5U1qEUC&pg=PP1&img=1&zoom=5&sig=2XmDi4HEhbqply9YjIsuopFQLAk",
      "preview"=>"noview"}]
    assert_equal(expected_array_of_hash, parsed_response)  
  end
  
  def test_dedupe
    cleaned_response = @gbs_default.clean_response(
      @response_three_duplicate_no_view)
    parsed_response = @gbs_default.parse_response(cleaned_response)
    deduped_response = @gbs_default.dedupe(parsed_response)
    expected_array_of_hash = [{
        "info_url"=>
          "http://books.google.com/books?id=E4R9AQAACAAJ&source=gbs_ViewAPI",
        "preview_url"=>
          "http://books.google.com/books?id=E4R9AQAACAAJ&source=gbs_ViewAPI",
        "preview"=>"noview",
        "bib_key"=>"ISBN:0393044548, OCLC:2985768, LCCN:76030648",
        "thumbnail_url"=>
          "http://bks3.books.google.com/books?id=E4R9AQAACAAJ&printsec=frontcover&img=1&zoom=5&sig=32ieZbDQYbQAeCNfW-vek8SfOxc"}]
    assert_equal(expected_array_of_hash, deduped_response)
  end
  
  def test_create_fulltext_service_response
    #flunk 'need to write fixture for a request'
  end
  
  def test_create_fulltext_service_response_nil
    request = requests(:frankenstein)
    fulltext_shown = @gbs_default.create_fulltext_service_response(request, 
      @data_frankenstein)
    assert_nil(fulltext_shown)
  end
  
  def test_find_thumbnail_url
    url = @gbs_default.find_thumbnail_url(@data_frankenstein)
    expected_url = 'http://bks3.books.google.com/books?id=92EbHgAACAAJ&printsec=frontcover&img=1&zoom=5&sig=ACfU3U10W3ycsrdiB-udzUYGnYtkVIp5tQ'
    assert_equal(expected_url, url)
  end
  
end
