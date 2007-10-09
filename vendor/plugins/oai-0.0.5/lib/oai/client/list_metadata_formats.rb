module OAI
  class ListMetadataFormatsResponse < Response
    include Enumerable
    include OAI::XPath

    def each 
      for format in xpath_all(@doc, './/metadataFormat')
        yield MetadataFormat.new(format)
      end
    end
  end
end
