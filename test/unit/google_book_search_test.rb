# tests for google book search service
# Only the the simplest of tests are done so far. To do more advanced tests,
# request fixtures for more cases should be created.

$:.unshift File.join(File.dirname(__FILE__),'..','lib')
require File.dirname(__FILE__) + '/../test_helper'

require 'test/unit'
require 'rubygems'

#require 'lib/service'
#require 'lib/metadata_helper'
#require 'lib/service_adaptors/google_book_search'

require 'yaml'

class GoogleBookSearchTest < Test::Unit::TestCase
  
  
  
  def setup
    
    
    @gbs_default = ServiceList.instance.instantiate!("GoogleBookSearch", nil)
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
   
    
    @data_frankenstein = Hpricot.XML("<?xml version=\"1.0\" encoding=\"UTF-8\"?><feed xmlns:gd=\"http://schemas.google.com/g/2005\" xmlns:dc=\"http://purl.org/dc/terms\" xmlns:gbs=\"http://schemas.google.com/books/2008\" xmlns:openSearch=\"http://a9.com/-/spec/opensearchrss/1.0/\" xmlns=\"http://www.w3.org/2005/Atom\"><id>http://www.google.com/books/feeds/volumes</id><updated>2009-04-29T22:02:42.000Z</updated><category term=\"http://schemas.google.com/books/2008#volume\" scheme=\"http://schemas.google.com/g/2005#kind\"></category><title type=\"text\">Search results for ISBN9780393964585 OR OCLC33045872</title><link href=\"http://www.google.com\" rel=\"alternate\" type=\"text/html\" /><link href=\"http://www.google.com/books/feeds/volumes\" rel=\"http://schemas.google.com/g/2005#feed\" type=\"application/atom+xml\" /><link href=\"http://www.google.com/books/feeds/volumes?q=ISBN9780393964585+OR+OCLC33045872\" rel=\"self\" type=\"application/atom+xml\" /><author><name>Google Books Search</name><uri>http://www.google.com</uri></author><generator version=\"beta\">Google Book Search data API</generator><openSearch:totalResults>1</openSearch:totalResults><openSearch:startIndex>1</openSearch:startIndex><openSearch:itemsPerPage>20</openSearch:itemsPerPage><entry><id>http://www.google.com/books/feeds/volumes/92EbHgAACAAJ</id><updated>2009-04-29T22:02:42.000Z</updated><category term=\"http://schemas.google.com/books/2008#volume\" scheme=\"http://schemas.google.com/g/2005#kind\"></category><title type=\"text\">Frankenstein</title><link href=\"http://bks5.books.google.com/books?id=92EbHgAACAAJ&amp;printsec=frontcover&amp;img=1&amp;zoom=5&amp;sig=ACfU3U10W3ycsrdiB-udzUYGnYtkVIp5tQ&amp;source=gbs_gdata\" rel=\"http://schemas.google.com/books/2008/thumbnail\" type=\"image/x-unknown\" /><link href=\"http://books.google.com/books?id=92EbHgAACAAJ&amp;dq=ISBN9780393964585+OR+OCLC33045872&amp;ie=ISO-8859-1&amp;source=gbs_gdata\" rel=\"http://schemas.google.com/books/2008/info\" type=\"text/html\" /><link href=\"http://books.google.com/books?id=92EbHgAACAAJ&amp;dq=ISBN9780393964585+OR+OCLC33045872&amp;ie=ISO-8859-1&amp;source=gbs_gdata\" rel=\"http://schemas.google.com/books/2008/preview\" type=\"text/html\" /><link href=\"http://www.google.com/books/feeds/users/me/volumes\" rel=\"http://schemas.google.com/books/2008/annotation\" type=\"application/atom+xml\" /><link href=\"http://books.google.com/books?id=92EbHgAACAAJ&amp;dq=ISBN9780393964585+OR+OCLC33045872&amp;ie=ISO-8859-1\" rel=\"alternate\" type=\"text/html\" /><link href=\"http://www.google.com/books/feeds/volumes/92EbHgAACAAJ\" rel=\"self\" type=\"application/atom+xml\" /><gbs:embeddability value=\"http://schemas.google.com/books/2008#not_embeddable\"></gbs:embeddability><gbs:openAccess value=\"http://schemas.google.com/books/2008#disabled\"></gbs:openAccess><gbs:viewability value=\"http://schemas.google.com/books/2008#view_no_pages\"></gbs:viewability><dc:creator>Mary Wollstonecraft Shelley</dc:creator><dc:creator>J. Paul Hunter</dc:creator><dc:date>1996-02-23</dc:date><dc:description>... ISBN9780393964585 9780393964585 LCCN95037928 OXFORD503855446 \r\nBIBoxford_UkOxUb11900853 BIBloc_95037928 OCLC78250571 OCLC33045872 ...</dc:description><dc:format>339 pages</dc:format><dc:identifier>92EbHgAACAAJ</dc:identifier><dc:identifier>ISBN:0393964582</dc:identifier><dc:identifier>ISBN:9780393964585</dc:identifier><dc:publisher>W. W. Norton &amp; Company</dc:publisher><dc:subject>Juvenile Fiction</dc:subject><dc:title>Frankenstein</dc:title><dc:title>The 1818 Text, Contexts, Nineteenth-century Responses, Modern Criticism</dc:title></entry></feed>")
    
    #@one_fake_full_fake_partial = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"full"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"partial"}});'
    #@two_fake_full = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"full"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"full"}});'
    #@one_fake_full_one_fake_noview = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"full"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"noview"}});'
    #@one_fake_partial_one_fake_noview = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"partial"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"noview"}});'
    #@two_no_view_one_fake_partial = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"noview"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"noview"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"partial"}});'
    #@two_full_one_fake_partial = 'gbscallback({"ISBN:0393044548":{"bib_key":"ISBN:0393044548","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks3.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=32ieZbDQYbQAeCNfW-vek8SfOxc","preview":"full"},"OCLC:2985768":{"bib_key":"OCLC:2985768","info_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks4.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=Z98qalA95yde4XY6VO-1ZF0tKlE","preview":"full"},"LCCN:76030648":{"bib_key":"LCCN:76030648","info_url":"http://books.google.com/books?id=E4R9AQAACAAJx\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=E4R9AQAACAAJ\x26source=gbs_ViewAPI","thumbnail_url":"http://bks5.books.google.com/books?id=E4R9AQAACAAJ\x26printsec=frontcover\x26img=1\x26zoom=5\x26sig=_qfxqS7dLZ7Oi48sFIBssQUbd4E","preview":"partial"}});'
    #@one_partial_view = 'gbscallback({"ISBN:030905382X":{"bib_key":"ISBN:030905382X","info_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26printsec=frontcover\x26sig=9-7ypznOwL_rECoKJLizCBpodds\x26source=gbs_ViewAPI","thumbnail_url":"http://bks7.books.google.com/books?id=XiiYq5U1qEUC\x26pg=PP1\x26img=1\x26zoom=5\x26sig=2XmDi4HEhbqply9YjIsuopFQLAk","preview":"partial"}});'
    #@one_fake_noview = 'gbscallback({"ISBN:030905382X":{"bib_key":"ISBN:030905382X","info_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26source=gbs_ViewAPI","preview_url":"http://books.google.com/books?id=XiiYq5U1qEUC\x26printsec=frontcover\x26sig=9-7ypznOwL_rECoKJLizCBpodds\x26source=gbs_ViewAPI","thumbnail_url":"http://bks7.books.google.com/books?id=XiiYq5U1qEUC\x26pg=PP1\x26img=1\x26zoom=5\x26sig=2XmDi4HEhbqply9YjIsuopFQLAk","preview":"noview"}});'
  end
  

  
  def test_initialize_minimum
    gbs = GoogleBookSearch.new({"priority"=>1})
    assert_equal(1, gbs.priority)
    assert_equal('Google Book Search', gbs.display_name)
    assert_equal(1, gbs.num_full_views)
    assert_equal(1, gbs.priority)
    assert_equal('standard', gbs.task)
  end
  
  def test_get_bibkeys
    f = referents(:frankenstein)
    keys = @gbs_default.get_bibkeys(f)
    expected = CGI.escape('ISBN9780393964585 OR OCLC33045872')
    assert_equal(expected, keys)
  end

  # Actually a live test of GBS server, not great, but oh well. 
  # This doesn't check much of the response, but just enough to know we got
  # something back. The server for the thumbnail changes, so we can't do a 
  # simple match and a huge regexp was making my head hurt.
  def test_do_query
    hpricot_response = @gbs_default.do_query('OCLC02364071', requests(:frankenstein))
    
    assert hpricot_response.at("dc:identifier")
  end

  
  def test_create_fulltext_service_response_nil
    request = requests(:frankenstein)
    fulltext_shown = @gbs_default.create_fulltext_service_response(request, 
      @data_frankenstein)
    assert_nil(fulltext_shown)
  end

  def test_find_thumbnail_url

    url = @gbs_default.find_thumbnail_url(@data_frankenstein)
    assert_not_nil url
  end
  
end
