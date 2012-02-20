# encoding: UTF-8

# 
# dissertation.rb
# 
# Created on Nov 1, 2007, 10:35:28 AM
# 
# To change this template, choose Tools | Templates
# and open the template in the editor.
 
require 'openurl/metadata_formats/scholarly_common'
module OpenURL
  class Dissertation < ScholarlyCommon
    
    def initialize
      super()
      @format = 'dissertation'
      @metadata_keys = ['title','co','cc','inst','advisor','date','tpages',
        'isbn','degree'
        ]
      @xml_ns = "info:ofi/fmt:xml:xsd:dissertation"
      @kev_ns = "info:ofi/fmt:kev:mtx:dissertation"
    end    
    def genre=(genre)
      raise ArgumentError, "Genre is not a valid #{self.class} metadata key."      
    end    
  end
  
  class DissertationFactory < ContextObjectEntityFactory
    @@identifiers = ["info:ofi/fmt:kev:mtx:dissertation","info:ofi/fmt:xml:xsd:dissertation"]
    def self.identifiers
      return @@identifiers
    end
    def self.create()
      return OpenURL::Dissertation.new
    end    
  end
end
