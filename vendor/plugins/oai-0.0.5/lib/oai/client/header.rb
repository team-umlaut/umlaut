module OAI
  class Header
    include OAI::XPath
    attr_accessor :status, :identifier, :datestamp, :set_spec

    def initialize(element)
      @status = get_attribute(element, 'status')
      @identifier = xpath(element, './/identifier')
      @datestamp = xpath(element, './/datestamp')
      @set_spec = xpath(element, './/setSpec')
    end

    def deleted?
      return true if @status.to_s == "deleted"
    end

  end
end
