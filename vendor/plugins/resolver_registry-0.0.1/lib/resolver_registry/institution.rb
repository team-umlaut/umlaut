module ResolverRegistry

  class Institution
    attr_reader :name, :ip_ranges, :oclc_inst_symbol, :domain_name, 
      :city, :state, :country, :resolvers

    # the constructor which takes an appropriate REXML::Element object
    # to extract info from
    def initialize(entry)
      @name = entry.elements['institutionName'].get_text.value if entry.elements['institutionName'] and entry.elements['institutionName'].has_text?

      @ip_ranges = []
      entry.each_element('IPAddressRange') { | range |
        @ip_ranges << range.get_text.value if range.has_text?
      }

      @oclc_inst_symbol = entry.elements['OCLCInstSymbol'].get_text.value if entry.elements['OCLCInstSymbol'] and entry.elements['OCLCInstSymbol'].has_text?
      @domain_name = entry.elements['institutionDomainName'].get_text.value if entry.elements['institutionDomainName'] and entry.elements['institutionDomainName'].has_text?

      if entry.elements['Address']
        @city = entry.elements['Address/City'].get_text.value if entry.elements['Address/City'] and entry.elements['Address/City'].has_text?
        @state = entry.elements['Address/State'].get_text.value if entry.elements['Address/State'] and entry.elements['Address/State'].has_text?      
        @country = entry.elements['Address/Country'].get_text.value if entry.elements['Address/Country'] and entry.elements['Address/Country'].has_text?
      end

      @resolvers = []
      entry.each_element('resolver') do |e|
        @resolvers << Resolver.new(e)
      end
    end

    # returns the first resolver
    def resolver
      return @resolvers[0]
    end

  end
end
