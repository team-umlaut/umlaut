# Doesn't yet cover everything, but started it to cover new func we wrote at least

require 'test_helper'
class MetadataHelperTest < ActiveSupport::TestCase  
  include MetadataHelper

  ContextObject = OpenURL::ContextObject


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
end