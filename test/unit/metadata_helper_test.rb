# Encoding: UTF-8

# Doesn't yet cover everything, but started it to cover new func we wrote at least

require 'test_helper'
class MetadataHelperTest < ActiveSupport::TestCase  
  include MetadataHelper

  ContextObject = OpenURL::ContextObject


  def test_get_search_title_i18n
    co = ContextObject.new_from_kev("sid=google&auinit=R&aulast=Dunayevskaya&title=Filosofía.+y+revolución:+de+Hegel+a+Sartre+y+de+Marx+a+Mao") 
    assert_equal "filosofía y revolución", get_search_title(co.referent)
  end

  def test_raw_search_title_regression
    co = ContextObject.new_from_kev("resolve?ctx_ver=Z39.88-2004&ctx_enc=info:ofi/enc:UTF-8&ctx_tim=2013-11-25T10%3A59%3A44IST&url_ver=Z39.88-2004&url_ctx_fmt=infofi/fmt:kev:mtx:ctx&rfr_id=info:sid/primo.exlibrisgroup.com:primo3-Article-sciversesciencedirect_elsevier&rft_val_fmt=info:ofi/fmt:kev:mtx:&rft.genre=article&rft.atitle=Supercritical water gasification of biomass: Thermodynamic constraints&rft.jtitle=Bioresource Technology&rft.btitle=&rft.aulast=Castello&rft.auinit=&rft.auinit1=&rft.auinitm=&rft.ausuffix=&rft.au=Castello%2C Daniele&rft.aucorp=&rft.date=2011&rft.volume=102&rft.issue=16&rft.part=&rft.quarter=&rft.ssn=&rft.spage=7574&rft.epage=7582&rft.pages=7574-7582&rft.artnum=&rft.issn=0960-8524&rft.eissn=&rft.isbn=&rft.sici=&rft.coden=&rft_id=info:doi/10.1016/j.biortech.2011.05.017&rft_dat=S0960-8524(11)00656-0&rft.eisbn=&rft_id=info:oai/")

    assert_equal "Bioresource Technology", raw_search_title(co.referent)
  end

  def test_get_isbn
    co = ContextObject.new_from_kev("isbn=079284937X")
    assert_equal "079284937X", get_isbn(co.referent)

    co = ContextObject.new_from_kev("rft.isbn=079284937X")
    assert_equal "079284937X", get_isbn(co.referent)

    co = ContextObject.new_from_kev("isbn=0-435-08441-0")
    assert_equal "0435084410", get_isbn(co.referent)

    co = ContextObject.new_from_kev("isbn=0435084410+%28pbk.%29")
    assert_equal "0435084410", get_isbn(co.referent)
  end

  def test_get_month    
    co = ContextObject.new_from_kev("date=2012-9-01&foo=bar")
    assert_equal "9", get_month(co.referent)

    co = ContextObject.new_from_kev("date=2012-10-01&foo=bar")
    assert_equal "10", get_month(co.referent)

    co = ContextObject.new_from_kev("date=2012-10&foo=bar")
    assert_equal "10", get_month(co.referent)

    co = ContextObject.new_from_kev("date=2012-10-01&month=9")
    assert_equal "10", get_month(co.referent)

    # If no date, try non-standard month
    co = ContextObject.new_from_kev("month=9&foo=bar")
    assert_equal "9", get_month(co.referent)
  end

  def test_get_spage
    co = ContextObject.new_from_kev("spage=20&epage=22&pages=unused&foo=bar")
    assert_equal "20", get_spage(co.referent)

    co = ContextObject.new_from_kev("pages=20+-+22&foo=bar")
    assert_equal "20", get_spage(co.referent)

    co = ContextObject.new_from_kev("pages=20&foo=bar")
    assert_equal "20", get_spage(co.referent)
  end

  def test_get_epage
    co = ContextObject.new_from_kev("spage=20&epage=22&pages=unused&foo=bar")
    assert_equal "22", get_epage(co.referent)

    co = ContextObject.new_from_kev("pages=20+-+22&foo=bar")
    assert_equal "22", get_epage(co.referent)

    co = ContextObject.new_from_kev("pages=20&foo=bar")
    assert_equal "20", get_epage(co.referent)
  end

  def test_title_is_serial
    # heuristics for guessing if a citation represents a Journal OR Article,
    # even in the presence of bad metadata, although we should respect good metadata. 

    assert_is_serial true,  "format=journal&genre=journal&issn=12345678&jtitle=Journal"
    assert_is_serial false, "format=book&issn=12345678&btitle=Book"
    assert_is_serial false, "genre=book&issn=12345678&title=Book"
    assert_is_serial false, "genre=bookitem&issn=12345678&btitle=Book"
    assert_is_serial true,  "jtitle=Journal&atitle=Article"
    assert_is_serial true,  "title=Journal&issn=12345678"
    assert_is_serial false, "genre=dissertation&title=Dissertation&issn=12345678"
  end
  # test title_is_serial? implementation, for use only there. 
  def assert_is_serial(true_or_false, citation_kev)
    co = ContextObject.new_from_kev(citation_kev)

    assert (!true_or_false == !title_is_serial?(co.referent)), "Expect title_is_serial('#{citation_kev}') to be #{true_or_false}"
  end

end