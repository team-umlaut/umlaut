# encoding: UTF-8

# 
# book.rb
# 
# Created on Oct 31, 2007, 1:07:33 PM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 
require 'openurl/metadata_formats/scholarly_common'
module OpenURL
  class Book < ScholarlyCommon     
    attr_reader :authors
    def initialize
      super()
      @format = 'book'
      @metadata_keys = ['btitle','atitle','title','place','pub','date','edition',
        'tpages','series', 'spage','epage', 'pages','issn','isbn','bici']
      @valid_genres = ["book","bookitem","conference","proceeding","report",
        "document","unknown" ]
      @xml_ns = "info:ofi/fmt:xml:xsd:book"
      @kev_ns = "info:ofi/fmt:kev:mtx:book"
    end
    
   
  end
  
  class BookFactory < ContextObjectEntityFactory
    @@identifiers = ["info:ofi/fmt:kev:mtx:book","info:ofi/fmt:xml:xsd:book"]
    def self.identifiers
      return @@identifiers
    end
    def self.create()
      return OpenURL::Book.new
    end    
  end
end
