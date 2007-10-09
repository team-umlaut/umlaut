require 'test_helper'

class XpathTest < Test::Unit::TestCase
  include OAI::XPath

  def test_rexml
    require 'rexml/document'
    doc = REXML::Document.new(File.new('test/test.xml'))
    assert_equal xpath(doc, './/responseDate'), '2006-09-11T14:33:15Z'
    assert_equal xpath(doc, './/foobar'), nil
  end

  def test_libxml
    begin 
      require 'xml/libxml'
    rescue
      # libxml not available so nothing to test!
      return
    end

    doc = XML::Document.file('test/test.xml')
    assert_equal xpath(doc, './/responseDate'), '2006-09-11T14:33:15Z'
    assert_equal xpath(doc, './/foobar'), nil
  end

end

__END__

