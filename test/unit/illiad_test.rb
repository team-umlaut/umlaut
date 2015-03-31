require 'test_helper'
require 'uri'

class IlliadTest < ActiveSupport::TestCase

  def setup
    @service       = Illiad.new('service_id' => 'test_illiad', 'base_url' => 'http://example.org/illiad.dll/OpenURL', 'priority' => 0)
  end

  def make_test_request(params)  
    # hard to figure out how to mock a request, this seems to work
    ActionController::TestRequest.new(Rack::MockRequest.env_for("?#{params.to_query}"))    
  end

  def execute_service(params)
    rails_request = make_test_request(params)
    umlaut_request = Request.find_or_create(params, {}, rails_request)
    @service.handle_wrapper(umlaut_request)
    return umlaut_request
  end

  def parsed_params_from_first_response(umlaut_request)
    response = umlaut_request.service_responses.first
    target_url = response.url
    target_url =~ %r{\Ahttp://example.org/illiad.dll/OpenURL\?(.*)\Z}
    query_string = $1
    out_params = CGI.parse(query_string)

    return out_params
  end

  def test_basic_case
    params = {
      'sid'     => 'SomeSource',
      'genre'   => 'article',
      'aulast'  => 'Smith',
      'aufirst' => 'John',
      'au'      => 'Smith, Johnny, Jr., Esq.',
      'volume'  => '100',
      'issue'   => '1',
      'spage'   => '500',
      'epage'   => '505',
      'pages'   => 'do not use',
      'issn'    => '12345678',
      'jtitle'  => 'Journal Of Lots Of Things',
      'stitle'  => 'J L Things',
      'atitle'  => 'Article Title',
      'date'    => '2011-05-12',
      'pub'     => 'Johnson Publishing',
      'place'   => 'Baltimore, MD',
      'edition' => '1st ed.'
    }

    umlaut_request = execute_service(params)
    

    assert_length 1, umlaut_request.service_responses

    response = umlaut_request.service_responses.first

    assert_equal "document_delivery", response.service_type_value_name

    target_url = response.url
    assert_present target_url
    assert_match %r{\Ahttp://example.org/illiad.dll/OpenURL\?(.*)\Z}, target_url


    target_url =~ %r{\Ahttp://example.org/illiad.dll/OpenURL\?(.*)\Z}
    query_string = $1
    out_params = CGI.parse(query_string)
    
    assert_equal ['SomeSource (via Umlaut)'], out_params['sid']

    # Ones that just get passed through
    ['genre', 'aulast', 'aufirst', 'volume', 'issue', 'spage', 'epage', 
      'issn', 'stitle', 'atitle'].each do |key|
        assert_equal [params[key]], out_params[key]
    end

    assert_equal ['2011'], out_params['year']
    assert_equal ['05'], out_params['month']

    assert_equal [params['jtitle']], out_params['title']

    assert_equal [params['pub']], out_params['rft.pub']
    assert_equal [params['place']], out_params['rft.place']
    assert_equal [params['edition']], out_params['rft.edition']

    assert_empty out_params['au']
  end

  def test_genre_dissertation_normalize    
    params = {
      'rft_val_fmt'=> 'info:ofi/fmt:kev:mtx:dissertation',
      'title' => 'our title',
      'au' => 'our author'
    }
    umlaut_request = execute_service(params)
    out_params = parsed_params_from_first_response(umlaut_request)  

    assert_equal ['dissertation'], out_params['genre']
    assert_equal ['our title'], out_params['title']
    assert_equal ['our author'], out_params['au']
  end

  def test_genre_bookitem_normalize
    params = {
      'genre' => 'book',
      'atitle' => 'Chapter Title',
      'title' => 'Book Title',
      'isbn'  => '978-3-16-148410-0'
    }
    umlaut_request = execute_service(params)
    out_params = parsed_params_from_first_response(umlaut_request)  

    assert_equal ['bookitem'], out_params['genre']
    assert_equal [params['atitle']], out_params['atitle']
    assert_equal [params['title']], out_params['title']
    assert_equal [params['isbn'].gsub('-', '')], out_params['isbn']
  end

  def test_genre_force_issn_article
    params = {
      'atitle' => "A title",
      'jtitle' => 'Journal Title',
      'issn'  => '12345678'
    }

    umlaut_request = execute_service(params)
    out_params = parsed_params_from_first_response(umlaut_request)  

    assert_equal ['article'], out_params['genre']
  end

  def test_genre_force_book
    params = {
      'title' => 'DVD Title?',
      'genre' => 'unknown',
      'isbn' => '978-3-16-148410-0'
    }
    umlaut_request = execute_service(params)
    out_params = parsed_params_from_first_response(umlaut_request)  

    assert_equal ['book'], out_params['genre']
  end
end
