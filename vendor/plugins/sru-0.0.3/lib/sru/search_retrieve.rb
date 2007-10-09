require 'sru/response'

module SRU
  
  # An iterator for search results which allows you to do stuff like:
  #
  # client = SRU::Client.new 'http://sru.example.com'
  # for record in client.search_retrieve('Mark Twain')
  #   puts record 
  # end
  
  class SearchResponse < Response
    include Enumerable

    def number_of_records
      return Integer(xpath('.//zs:numberOfRecords'))
    end

    # Returns the contents of each recordData element in a 
    # SRU searchRetrieve response.
   
    def each
      for record_data in xpath_all('.//zs:recordData')
        if record_data.elements.size > 0
          yield record_data.elements[1]
        end
      end
    end
  end
end
