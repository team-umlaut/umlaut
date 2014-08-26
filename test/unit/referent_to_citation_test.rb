require 'test_helper'

# Some basic tests for referent.to_citation, which returns a hash of various citation
# information. 
class ReferentToCitationTest < ActiveSupport::TestCase
  # referent = make_test_referent("title=foo&au=bar&genre=book")
  def make_test_referent(openurl_kev)
    co = OpenURL::ContextObject.new_from_kev( openurl_kev )
    ref = Referent.create_by_context_object( co )

    return ref
  end

  def test_simple_book
    # an exmaple from Borrow Direct as it happens
    ref = make_test_referent("genre=Book&sid=BD&rft.title=The%20monk&rft.aufirst=%20M.%20G.&rft.aulast=Lewis&rft.date=1797&rft.pub=Printed%20by%20William%20Porter&rft.place=Dublin&umlaut.force_new_request=true")
    cit_hash = ref.to_citation

    assert_equal "The monk",      cit_hash[:title]
    assert_equal "1797",          cit_hash[:date]
    assert_equal "Lewis, M. G.",  cit_hash[:author]
    assert_equal "Book Title",    cit_hash[:title_label]
    assert_equal "Printed by William Porter", cit_hash[:pub]
  end

  def test_article
    # an article from Google Scholar
    ref = make_test_referent("sid=google&auinit=S&aulast=Madsbad&atitle=Mechanisms+of+changes+in+glucose+metabolism+and+bodyweight+after+bariatric+surgery&id=doi:10.1016/S2213-8587(13)70218-3&title=The+Lancet+Diabetes+%26+Endocrinology&volume=2&issue=2&date=2014&spage=152&issn=2213-8587")
    cit_hash = ref.to_citation

    assert_equal "Mechanisms of changes in glucose metabolism and bodyweight after bariatric surgery",
      cit_hash[:title]
    assert_equal "Article Title", cit_hash[:title_label]
    assert_equal "The Lancet Diabetes & Endocrinology", cit_hash[:container_title]
    assert_equal "Journal", cit_hash[:container_label]
    assert_equal "22138587", cit_hash[:issn]
    assert_equal "2", cit_hash[:volume]
    assert_equal "2", cit_hash[:issue]
    assert_equal "2014", cit_hash[:date]
    assert_equal "Madsbad, S", cit_hash[:author]
    assert_equal "152", cit_hash[:page]
    assert_equal ["info:doi/10.1016/S2213-8587(13)70218-3"], cit_hash[:identifiers]
  end

  def test_type_of_thing
    I18n.locale = "en"

    ref = make_test_referent("&genre=dissertation&title=Foo&au=Smith")
    assert_equal I18n.t("umlaut.citation.genre.dissertation"), ref.type_of_thing
    assert_equal I18n.t("umlaut.citation.genre.dissertation"), ref.container_type_of_thing

    ref = make_test_referent("rft_val_fmt=info:ofi/fmt:kev:mtx:dissertation&title=Foo")
    assert_equal I18n.t("umlaut.citation.genre.dissertation"), ref.type_of_thing

    ref = make_test_referent("sid=google&auinit=S&aulast=Madsbad&atitle=Mechanisms+of+changes+in+glucose+metabolism+and+bodyweight+after+bariatric+surgery&id=doi:10.1016/S2213-8587(13)70218-3&title=The+Lancet+Diabetes+%26+Endocrinology&volume=2&issue=2&date=2014&spage=152&issn=2213-8587")
    assert_equal I18n.t("umlaut.citation.genre.article"), ref.type_of_thing
    assert_equal I18n.t("umlaut.citation.genre.journal"), ref.container_type_of_thing

    ref = make_test_referent("genre=bookitem&atitle=a+chapter&title=a+book")
    assert_equal I18n.t("umlaut.citation.genre.bookitem"), ref.type_of_thing
    assert_equal I18n.t("umlaut.citation.genre.book"), ref.container_type_of_thing

    ref = make_test_referent("genre=unknown&atitle=a+chapter&title=a+book")
    assert_nil ref.type_of_thing
    assert_nil ref.container_type_of_thing

    ref = make_test_referent("genre=invalid_made_up&atitle=a+chapter&title=a+book")
    assert_nil ref.type_of_thing
    assert_nil ref.container_type_of_thing
  end

end
