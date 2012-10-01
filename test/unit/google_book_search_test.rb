# tests for google book search service
# Only the the simplest of tests are done so far. To do more advanced tests,
# request fixtures for more cases should be created.
require 'test_helper'
class GoogleBookSearchTest < ActiveSupport::TestCase  
  extend TestWithCassette
  fixtures :requests, :referents
  
  def setup    
    @gbs_default = ServiceStore.instantiate_service!("GoogleBookSearch", nil)
    
    @data_frankenstein = 
      {"totalItems"=>1, "kind"=>"books#volumes", "items"=>[{"accessInfo"=>{"embeddable"=>true, "webReaderLink"=>"http://books.google.com/books/reader?id=QKgVAAAAYAAJ&as_pt=BOOKS&printsec=frontcover&output=reader&source=gbs_api", "epub"=>{"isAvailable"=>true, "downloadLink"=>"http://books.google.com/books/download/Frankenstein.epub?id=QKgVAAAAYAAJ&output=epub&source=gbs_api"}, "viewability"=>"ALL_PAGES", "publicDomain"=>true, "country"=>"US", "pdf"=>{"isAvailable"=>true, "downloadLink"=>"http://books.google.com/books/download/Frankenstein.pdf?id=QKgVAAAAYAAJ&output=pdf&sig=ACfU3U3nhOFhUroWh_b-nMaAulaAV6kjlw&source=gbs_api"}, "textToSpeechPermission"=>"ALLOWED", "accessViewStatus"=>"FULL_PUBLIC_DOMAIN"}, "searchInfo"=>{"textSnippet"=>"FRANKENSTEIN or The Modern Prometheus CHAPTER I. I Am by birth a Genevese; and <br>  my family is one of the most distinguished of that republic. My ancestors had <br>  been for many years counselors and syndics; and my father had filled several <b>...</b>"}, "etag"=>"TUqYf+e+c9k", "kind"=>"books#volume", "volumeInfo"=>{"infoLink"=>"http://books.google.com/books?id=QKgVAAAAYAAJ&dq=OCLC2364071&as_pt=BOOKS&source=gbs_api", "contentVersion"=>"0.0.1.0.full.3", "categories"=>["Fiction"], "title"=>"Frankenstein", "printType"=>"BOOK", "ratingsCount"=>279, "subtitle"=>"or, the Modern Prometheus", "previewLink"=>"http://books.google.com/books?id=QKgVAAAAYAAJ&printsec=frontcover&dq=OCLC2364071&as_pt=BOOKS&cd=1&source=gbs_api", "imageLinks"=>{"smallThumbnail"=>"http://bks6.books.google.com/books?id=QKgVAAAAYAAJ&printsec=frontcover&img=1&zoom=5&edge=curl&source=gbs_api", "thumbnail"=>"http://bks6.books.google.com/books?id=QKgVAAAAYAAJ&printsec=frontcover&img=1&zoom=1&edge=curl&source=gbs_api"}, "pageCount"=>332, "language"=>"en", "canonicalVolumeLink"=>"http://books.google.com/books/about/Frankenstein.html?id=QKgVAAAAYAAJ", "averageRating"=>4.0, "authors"=>["Mary Wollstonecraft Shelley"], "industryIdentifiers"=>[{"type"=>"OTHER", "identifier"=>"PRNC:32101064790353"}], "publishedDate"=>"1922"}, "saleInfo"=>{"isEbook"=>true, "saleability"=>"FREE", "country"=>"US"}, "id"=>"QKgVAAAAYAAJ", "selfLink"=>"https://www.googleapis.com/books/v1/volumes/QKgVAAAAYAAJ"}]}      
    
  end

  def test_initialize_minimum
    gbs = GoogleBookSearch.new({"priority"=>1})
    assert_equal(1, gbs.priority)    
    assert_equal('Google Books', gbs.display_name)
    assert_equal(1, gbs.num_full_views)
    assert_equal(1, gbs.priority)
    assert_equal('standard', gbs.task)
  end
  
  def test_get_bibkeys
    f = referents(:frankenstein)
    keys = @gbs_default.get_bibkeys(f)
    expected = CGI.escape('isbn:9780393964585 OR "OCLC33045872"')
    assert_equal(expected, keys)
  end

  # Actually a live test of GBS server, not great, but oh well. 
  # This doesn't check much of the response, but just enough to know we got
  # something back. The server for the thumbnail changes, so we can't do a 
  # simple match and a huge regexp was making my head hurt.
  # UPDATE: Use VCR to provide a deterministic GBS search.
  # TODO: Check more of the response
  test_with_cassette("search frankenstein by OCLC number", :google_book_search) do
    hashified_response = @gbs_default.do_query('OCLC2364071', requests(:frankenstein))
    assert_not_nil hashified_response
    assert_not_nil hashified_response["totalItems"]
    assert_operator hashified_response["totalItems"], :>, 0 
  end

  def test_create_fulltext_service_response
    # frankenstein's got fulltext now. 
    request = requests(:frankenstein)
    fulltext_shown = 
      @gbs_default.create_fulltext_service_response(request, @data_frankenstein)
    assert(fulltext_shown)
  end

  def test_find_thumbnail_url
    url = @gbs_default.find_thumbnail_url(@data_frankenstein)
    assert_not_nil url
  end
end