module OAI
  class ListIdentifiersResponse < Response
    include Enumerable
    include OAI::XPath

    def each
      for header_element in xpath_all(@doc, './/ListIdentifiers/header')
        yield OAI::Header.new(header_element)
      end
    end
  end
end
