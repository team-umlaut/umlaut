module SRU

  # a class for representing a term in the response from a sru server
  class Term < Response
    attr_accessor :value, :number_of_records, :displayTerm, :whereInList, 
      :extraTermData

    def initialize(element)
      super element
      @value = xpath('value')
      @number_of_records = xpath('numberOfRecords')
      @display_term = xpath('displayTerm')
      @whereInList = xpath('whereInList')
      @extraTermData = xpath_first('extraTermData')
    end
  end
end
