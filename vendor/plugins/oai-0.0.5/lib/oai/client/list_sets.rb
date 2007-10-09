module OAI

  # allows for iteration of the sets found in a oai-pmh server
  #
  #   for set in client.list_sets
  #     puts set
  #   end
  
  class ListSetsResponse < Response
    include OAI::XPath
    include Enumerable

    def each
      for set_element in xpath_all(@doc, './/set')
        yield OAI::Set.parse(set_element)
      end
    end
  end
end
