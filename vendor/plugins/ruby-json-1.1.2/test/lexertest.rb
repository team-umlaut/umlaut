#
# Unit tests for JSON Lexer
#  Copyright (C) 2003 Rafael R. Sevilla <dido@imperium.ph>
#  This file is part of JSON for Ruby
#
#  JSON for Ruby is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public License
#  as published by the Free Software Foundation; either version 2.1 of
#  the License, or (at your option) any later version.
#
#  JSON for Ruby is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details. 
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with JSON for Ruby; if not, write to the Free
#  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
#  02111-1307 USA.
#
# Author:: Rafael R. Sevilla (mailto:dido@imperium.ph)
# Copyright:: Copyright (c) 2003 Rafael R. Sevilla
# License:: GNU Lesser General Public License
# $Id: lexertest.rb,v 1.3 2005/01/28 03:03:51 didosevilla Exp $
#

require 'test/unit'
#require 'test/unit/ui/console/testrunner'
require 'json/lexer'
require 'json/objects'

class LexerTest < Test::Unit::TestCase
  def test_nextchar_back
    str = "some_string"
    lex = JSON::Lexer.new(str)
    c = lex.nextchar
    assert(c == 's', "wrong character read")
    lex.back
    c = lex.nextchar
    assert(c == 's', "backing up produces inconsistent results")
  end

  def test_ending
    lex = JSON::Lexer.new("ab")
    lex.nextchar
    assert(lex.more?, "more? method produces wrong results (no more when there should be more)")
    lex.nextchar
    assert(!lex.more?, "more? method produces wrong results (more when there are no more)")
  end

  def test_nextmatch
    lex = JSON::Lexer.new("abc")
    c = ""
    assert_nothing_raised {
      c = lex.nextmatch('a')
    }
    assert(c == 'a', "nextmatch is wrong")
    assert_raises(RuntimeError, "exception not raised for not found") {
      c = lex.nextmatch('a')
    }
  end

  def test_nextchars
    lex = JSON::Lexer.new("some_string")
    str = lex.nextchars(4)
    assert(str == 'some', "nextchars doesn't work correctly")
    assert_raises(RuntimeError, "exception not raised for substring bounds error") {
      lex.nextchars(10)
    }
  end

  def test_nextclean
    str1 = "/\t// comment\nb"
    lex = JSON::Lexer.new(str1)
    assert(lex.nextclean == '/', "nextclean seems to have problems")
    assert(lex.nextclean == 'b', "// comment processing has problems")
    str2 = "/ /* comment */b"
    lex = JSON::Lexer.new(str2)
    assert(lex.nextclean == '/', "nextclean seems to have problems")
    assert(lex.nextclean == 'b', "/* .. */ comment processing has problems")
    # test unclosed comments
    lex = JSON::Lexer.new("a/* unclosed comment")
    assert(lex.nextclean == 'a', "nextclean seems to have problems")
    assert_raises(RuntimeError, "unclosed comment doesn't raise exceptions") {
      lex.nextclean
    }
  end

  def test_nextstring
    str1 = "str\""
    lex = JSON::Lexer.new(str1)
    assert(lex.nextstring('"') == "str", "string processing has problems")
    str2 = '\b\t\n\f\r"'
    lex = JSON::Lexer.new(str2)
    assert(lex.nextstring('"') == "\b\t\n\f\r", "escape sequence processing has bugs")
    # UTF8 conversion tests for escape sequences
    str3 = '\u1234"'
    lex = JSON::Lexer.new(str3)
    assert(lex.nextstring('"') == "\341\210\224", "Unicode escape sequence processing has bugs")
  end

  def test_nextvalue
    str = "false"
    lex = JSON::Lexer.new(str)
    assert(lex.nextvalue == false, "error parsing false");

    str = "true"
    lex = JSON::Lexer.new(str)
    assert(lex.nextvalue == true, "error parsing true");

    str = "31337"
    lex = JSON::Lexer.new(str)
    assert(lex.nextvalue == 31337, "error parsing integer");

    str = "0.577289"
    lex = JSON::Lexer.new(str)
    assert(lex.nextvalue == 0.577289, "error parsing float")

    str = "\"123\n\""
    lex = JSON::Lexer.new(str)
    assert(lex.nextvalue == "123\n", "error parsing string")

    str = "null"
    lex = JSON::Lexer.new(str)
    assert(lex.nextvalue.nil?, "error parsing null")

    str = "[ 1, \"abc\", 2.7182818 ]"
    lex = JSON::Lexer.new(str)
    array = lex.nextvalue
    assert(array[0] == 1, "error parsing an array (0th elem)")
    assert(array[1] == "abc", "error parsing an array (1st elem)")
    assert(array[2] = 2.7182818, "error parsing an array (2nd elem)")

    str = '{"foo":"bar", "xyz":1, "e":2.7182818}'
    lex = JSON::Lexer.new(str)
    obj = lex.nextvalue
    assert(obj["foo"] == "bar", "error parsing an object ('foo' elem)")
    assert(obj["xyz"] == 1, "error parsing an object ('xyz' elem)")
    assert(obj["e"] == 2.7182818, "error parsing an object ('e' elem)")

    str = "false"
    lex = JSON::Lexer.new(str)
    assert(lex.nextvalue == false, "error parsing false");
  end
end

