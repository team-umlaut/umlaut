module OAI
  class GetRecordResponse < Response
    include OAI::XPath
    attr_accessor :record

    def initialize(doc)
      super doc
      @record = OAI::Record.new(xpath_first(doc, './/GetRecord/record'))
    end

    def deleted?
      return @record.deleted?
    end
  end
end
