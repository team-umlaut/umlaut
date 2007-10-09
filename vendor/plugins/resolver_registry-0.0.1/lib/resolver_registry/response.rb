module ResolverRegistry

  class Response
    include Enumerable

    attr_reader :institutions

    def initialize(xml)
      @institutions = []
      doc = REXML::Document.new(xml)
      doc.each_element('records/resolverRegistryEntry') do |e|
        @institutions << Institution.new(e)
      end
    end

    def each
      @institutions.each {|i| yield i}
    end

    def institution
      return @institutions[0]
    end
  end
end
