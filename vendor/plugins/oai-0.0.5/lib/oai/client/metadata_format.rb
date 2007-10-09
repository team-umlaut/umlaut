module OAI
  class MetadataFormat
    include OAI::XPath
    attr_accessor :prefix, :schema, :namespace

    def initialize(element)
      @prefix = xpath(element, './/metadataPrefix')
      @schema = xpath(element, './/schema')
      @namespace = xpath(element, './/metadataNamespace')
    end
  end
end
