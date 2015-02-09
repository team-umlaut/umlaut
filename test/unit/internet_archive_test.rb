# Encoding: UTF-8

# tests for internet archive service
# Only the the simplest of tests are done so far. To do more advanced tests,
# request fixtures for more cases should be created.
require 'test_helper'
class InternetArchiveTest < ActiveSupport::TestCase  
  extend TestWithCassette

  def setup    
    @ia_default = ServiceStore.instantiate_service!("InternetArchive", nil)
  end

  test_with_cassette("momo by title author", :internet_archive) do    
    request = fake_umlaut_request("/resolve?isbn=038519093X&aufirst=Michael&aulast=Ende&btitle=Momo&genre=book&isbn=038519093X&pub=Doubleday")
    
    # Clear out the current responses.
    request.service_responses.each do |service_response|
      service_response.destroy
    end
    @ia_default.handle(request)
    request.referent.referent_values.reset
    request.dispatched_services.reset
    request.service_responses.reset
    fulltexts = request.get_service_type('fulltext')
    assert((not fulltexts.empty?), "IA didn't return any fulltext")
    assert_equal(1, fulltexts.length, "IA returned an unexpected number of fulltexts")
    fulltext = fulltexts.first
    assert_equal("http://archive.org/details/MomoOvveroLarcanaStoriaDeiLadriDiTempoEDellaBambinaCheRestitu", 
      fulltext.url, "IA Service constructed an unexpected URL")
    view_data = fulltext.view_data
    assert((not view_data.nil?), "IA full text view data is nil")

    assert_equal("the Internet Archive: Open Source Books", view_data[:display_text], "IA display text is unexpected")

    assert_equal "Momo, ovvero l'arcana storia dei ladri di tempo e della bambina che restituÃ¬ agli uomini il tempo trafugato / Michael Ende", view_data[:edition_str]
    assert_equal ServiceResponse::MatchUnsure, view_data[:match_reliability]
  end

  test_with_cassette("style no good match", :internet_archive) do
    request = fake_umlaut_request("/resolve?rft.genre=book&rft.aulast=Williams&rft.date=2012&rft.isbn=9780205830763&rft.btitle=Style%3A+the+basics+of+clarity+and+grace&rft.place=Boston&rft.pub=Longman&rft.edition=4th+ed&rft.tpages=147&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook&rft_id=info%3Aoclcnum%2F653483714&rft_id=info%3Alccn%2F2010032819")

    @ia_default.handle(request)

    assert_service_responses(request, "InternetArchive", :number => 0, :includes_type => :fulltext)
  end

  test_with_cassette("twain no good match", :internet_archive) do
    request = fake_umlaut_request("/resolve?rft.genre=book&rft.aulast=Paine&rft.date=1912&rft.btitle=Mark+Twain%3A+a+biography%3B+the+personal+and+literary+life+of+Samuel+Langhorne+Clemens&rft.place=New+York+and+London&rft.pub=Harper+%26+brothers&rft_val_fmt=info%3Aofi%2Ffmt%3Akev%3Amtx%3Abook&rft_id=info%3Alccn%2F12022977")

    @ia_default.handle(request)

    assert_nil request.service_responses.to_a.find {|sr| sr.service_type_value == "fulltext"}
  end

  test_with_cassette("Stalin tricky good match", :internet_archive) do
    request = fake_umlaut_request("/resolve?sid=google&auinit=B&aulast=Souvarine&title=Stalin%3A+A+Critical+Survey+of+Bolshevism&genre=book&isbn=0374975205&date=1939")

    @ia_default.handle(request)

    fulltext = assert_service_responses(request, "InternetArchive", :includes_type => "fulltext", :number => 1)

    fulltext_view_data = fulltext.view_data

    assert_equal "the Internet Archive: Universal Digital Library", fulltext_view_data["display_text"]
    assert_equal "http://archive.org/details/stalinacriticals027965mbp", fulltext_view_data["url"]

    assert_equal "Stalin A Critical Survey Of Bolshevism / Boris Souvarine. Alliance Book Corporation: 1939", fulltext_view_data["edition_str"]
    assert_equal ServiceResponse::MatchUnsure, fulltext_view_data[:match_reliability]
  end

  test_with_cassette("capital with variety of links", :internet_archive) do
    request = fake_umlaut_request("/resolve?sid=google&auinit=K&aulast=Marx&title=Capital+(Volume+1:+A+Critique+of+Political+Economy):+A+Critique+of+Political+Economy&genre=book&isbn=1420906712&date=2004")

    @ia_default.handle(request)

    responses = assert_service_responses(request, "InternetArchive", :includes_type => [:fulltext, :audio, :highlighted_link], :number => 3)
    
    fulltext = responses.find_all {|r| r.service_type_value_name == "fulltext"}
    assert_length 1, fulltext
    fulltext_view = fulltext.first.view_data
    assert_equal "the Internet Archive: Harvard University", fulltext_view[:display_text]
    assert_equal "http://archive.org/details/capital00marxgoog", fulltext_view[:url]
    # Weird comma is in IA data, that's the publisher "Nelson, 1906"
    assert_equal "Capital / Karl Marx. Nelson, 1906", fulltext_view[:edition_str]

    audio = responses.find_all {|r| r.service_type_value_name == "audio"}
    assert_length 1, audio
    audio_view = audio.first.view_data
    assert_equal "the Internet Archive: LibriVox", audio_view[:display_text]
    assert_equal "http://archive.org/details/capital_vol1_0810_librivox", audio_view[:url]
    assert_equal "Capital: A Critical Analysis of Capitalist Production, Volume 1 / Karl Marx. LibriVox", audio_view[:edition_str]

    highlighted = responses.find_all {|r| r.service_type_value_name == "highlighted_link"}
    assert_length 1, highlighted
    
    assert highlighted.find {|sr| sr.view_data[:display_text] =~ /digital text files/ && sr.view_data[:url] =~ %r{^http://www\.archive\.org/search\.php\?query}}    
  end



end

