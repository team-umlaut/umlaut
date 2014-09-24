# tests for google book search service
# Only the the simplest of tests are done so far. To do more advanced tests,
# request fixtures for more cases should be created.
require 'test_helper'
class GoogleBookSearchTest < ActiveSupport::TestCase  
  extend TestWithCassette
  
  def setup    
    @gbs_default = ServiceStore.instantiate_service!("GoogleBookSearch", nil)
    
    @data_frankenstein = 
      {"totalItems"=>1, "kind"=>"books#volumes", "items"=>[{"accessInfo"=>{"embeddable"=>true, "webReaderLink"=>"http://books.google.com/books/reader?id=QKgVAAAAYAAJ&as_pt=BOOKS&printsec=frontcover&output=reader&source=gbs_api", "epub"=>{"isAvailable"=>true, "downloadLink"=>"http://books.google.com/books/download/Frankenstein.epub?id=QKgVAAAAYAAJ&output=epub&source=gbs_api"}, "viewability"=>"ALL_PAGES", "publicDomain"=>true, "country"=>"US", "pdf"=>{"isAvailable"=>true, "downloadLink"=>"http://books.google.com/books/download/Frankenstein.pdf?id=QKgVAAAAYAAJ&output=pdf&sig=ACfU3U3nhOFhUroWh_b-nMaAulaAV6kjlw&source=gbs_api"}, "textToSpeechPermission"=>"ALLOWED", "accessViewStatus"=>"FULL_PUBLIC_DOMAIN"}, "searchInfo"=>{"textSnippet"=>"FRANKENSTEIN or The Modern Prometheus CHAPTER I. I Am by birth a Genevese; and <br>  my family is one of the most distinguished of that republic. My ancestors had <br>  been for many years counselors and syndics; and my father had filled several <b>...</b>"}, "etag"=>"TUqYf+e+c9k", "kind"=>"books#volume", "volumeInfo"=>{"infoLink"=>"http://books.google.com/books?id=QKgVAAAAYAAJ&dq=OCLC2364071&as_pt=BOOKS&source=gbs_api", "contentVersion"=>"0.0.1.0.full.3", "categories"=>["Fiction"], "title"=>"Frankenstein", "printType"=>"BOOK", "ratingsCount"=>279, "subtitle"=>"or, the Modern Prometheus", "previewLink"=>"http://books.google.com/books?id=QKgVAAAAYAAJ&printsec=frontcover&dq=OCLC2364071&as_pt=BOOKS&cd=1&source=gbs_api", "imageLinks"=>{"smallThumbnail"=>"http://bks6.books.google.com/books?id=QKgVAAAAYAAJ&printsec=frontcover&img=1&zoom=5&edge=curl&source=gbs_api", "thumbnail"=>"http://bks6.books.google.com/books?id=QKgVAAAAYAAJ&printsec=frontcover&img=1&zoom=1&edge=curl&source=gbs_api"}, "pageCount"=>332, "language"=>"en", "canonicalVolumeLink"=>"http://books.google.com/books/about/Frankenstein.html?id=QKgVAAAAYAAJ", "averageRating"=>4.0, "authors"=>["Mary Wollstonecraft Shelley"], "industryIdentifiers"=>[{"type"=>"OTHER", "identifier"=>"PRNC:32101064790353"}], "publishedDate"=>"1922"}, "saleInfo"=>{"isEbook"=>true, "saleability"=>"FREE", "country"=>"US"}, "id"=>"QKgVAAAAYAAJ", "selfLink"=>"https://www.googleapis.com/books/v1/volumes/QKgVAAAAYAAJ"}]}      
    
    @frankenstein_request = fake_umlaut_request("/resolve?isbn=9780393964585&oclcnum=33045872&aufirst=Mary&auinitm=Wollstonecraft&aulast=Shelley&btitle=Frankenstein+%3A+the+1818+text%2C+contexts%2C+nineteenth-century+responses%2C+modern+criticism&date=1997&edition=1st+ed.&genre=book&place=New+York&pub=W.W.+Norton")
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
    keys = @gbs_default.get_bibkeys(@frankenstein_request.referent)
    expected = CGI.escape('isbn:9780393964585 OR "OCLC33045872"')
    assert_equal(expected, keys)
  end



  test_with_cassette("frankenstein by OCLC number", :google_book_search) do
    hashified_response = @gbs_default.do_query('OCLC2364071', @frankenstein_request)
    assert_not_nil hashified_response
    assert_not_nil hashified_response["totalItems"]
    assert_operator hashified_response["totalItems"], :>, 0 
  end

  test_with_cassette("enhances referent and other data", :google_book_search) do
    request = fake_umlaut_request("/?isbn=1416573461") # an edition of gone with the wind
    @gbs_default.handle(request)

    ref_metadata = request.referent.metadata

    assert_equal "Gone with the Wind", ref_metadata["title"]
    assert_equal "Margaret Mitchell", ref_metadata["au"]
    assert_equal "Simon and Schuster", ref_metadata["pub"]
    assert_equal "960", ref_metadata["tpages"]
    assert_equal "2007", ref_metadata["date"]
  end

  test_with_cassette("adds abstract", :google_book_search) do
    # an edition of gone with the wind
    request               = fake_umlaut_request("/?isbn=1416573461") 
    service_with_abstract = GoogleBookSearch.new('priority' => 1, 'abstract' => true, 'service_id' => 'GoogleBookSearch')

    service_with_abstract.handle(request)

    abstract = request.service_responses.to_a.find {|sr| sr.service_type_value == ServiceTypeValue["abstract"] && sr.service_id == "GoogleBookSearch"}
    assert abstract, "Did not create an `abstract` ServiceResponse"
    assert_present abstract.display_text , "`abstract` ServiceResponse missing content"
    assert_present abstract.url, "`abstract` ServiceResposne missing url"
  end

  def test_create_fulltext_service_response
    # frankenstein's got fulltext now.     
    fulltext_shown = 
      @gbs_default.create_fulltext_service_response(@frankenstein_request, @data_frankenstein)
    assert(fulltext_shown)
  end

  def test_find_thumbnail_url
    url = @gbs_default.find_thumbnail_url(@data_frankenstein)
    assert_not_nil url
  end
end