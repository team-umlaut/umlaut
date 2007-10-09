#!/usr/bin/env ruby

$LOAD_PATH.unshift 'lib'

require 'test/unit'
require 'xisbn'
include XISBN

class XISBNTest < Test::Unit::TestCase

  def test_lookup
    isbns = xisbn('0192816640')
    assert isbns.length > 0
  end

  def test_lookup_with_dashes
    isbns = xisbn('01928-16-640')
    assert isbns.length > 0
  end

  def test_bad_lookup
    isbns = xisbn('foobar')
    assert isbns.length == 0
  end

  def test_timeout
    isbns = xisbn('foobar', :timeout=>2)
  end

  def test_thing_isbn
    isbns = thing_isbn('01928-16-640')
    assert isbns.length > 0
  end

end
