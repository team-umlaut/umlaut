module OAI

  # A class for representing a Record as returned from a GetRecord 
  # or ListRecords request. Each record will have a header and metadata
  # attribute. The header is a OAI::Header object and the metadata is 
  # a REXML::Element object for that chunk of XML. 
  #
  # Note: if your OAI::Client was configured to use the 'libxml' parser
  # metadata will return a XML::Node object instead.
  
  class Record
    include OAI::XPath
    attr_accessor :header, :metadata

    def initialize(element)
      @header = OAI::Header.new xpath_first(element, './/header')
      @metadata = xpath_first(element, './/metadata')
    end

    # a convenience method which digs into the header status attribute
    # and returns true if the value is set to 'deleted'
    def deleted?
      return @header.deleted?
    end
  end
end
