module OAI
  class IdentifyResponse < Response
    include OAI::XPath
    attr_accessor :repository_name, :base_url, :protocol, :admin_email, 
      :earliest_datestamp, :deleted_record, :granularity, :compression

    def initialize(doc)
      super doc
      @repository_name = xpath(doc, './/Identify/repositoryName')
      @base_url = xpath(doc, './/Identify/baseURL')
      @protocol = xpath(doc, './/Identify/protocol')
      @admin_email = xpath(doc, './/Identify/adminEmail')
      @earliest_datestamp = xpath(doc, './/Identify/earliestDatestamp')
      @deleted_record = xpath(doc, './/Identify/deletedRecord')
      @granularity = xpath(doc, './/Identify/granularity')
      @compression = xpath(doc, '..//Identify/compression')
    end

    def to_s
      return "#{@repository_name} [#{@base_url}]"
    end

    # returns REXML::Element nodes for each description section
    # if the OAI::Client was configured to use libxml then you will
    # instead get a XML::Node object.
    def descriptions
      return xpath_all(doc, './/Identify/description')
    end
  end
end
