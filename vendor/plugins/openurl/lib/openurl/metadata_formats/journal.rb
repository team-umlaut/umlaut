# encoding: UTF-8

# 
# journal.rb
# 
# Created on Nov 1, 2007, 10:35:28 AM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 
require 'openurl/metadata_formats/scholarly_common'
module OpenURL
  class Journal < ScholarlyCommon
    
    def initialize
      super()
      @format = 'journal'
      @metadata_keys = ['jtitle','atitle','title','stitle','place','pub','date','edition',
        'spage','epage', 'pages','issn','eissn', 'isbn','sici','coden','chron',
        'ssn','quarter','volume','part','issue','artnum'
        ]
      @valid_genres = ["journal","issue","article", "conference","proceeding",
        "preprint","unknown" ]
      @xml_ns = "info:ofi/fmt:xml:xsd:journal"
      @kev_ns = "info:ofi/fmt:kev:mtx:journal"
    end      
  end
  
  class JournalFactory < ContextObjectEntityFactory
    @@identifiers = ["info:ofi/fmt:kev:mtx:journal","info:ofi/fmt:xml:xsd:journal"]
    def self.identifiers
      return @@identifiers
    end
    def self.create()
      return OpenURL::Journal.new
    end    
  end
end
