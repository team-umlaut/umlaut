module Exlibris::Aleph
  class Record < RestAPI
    def initialize(bib_library, record_id, uri)
      @record_id = record_id
      raise "Initialization error in #{self.class}. Missing record id." if @record_id.nil?
      @bib_library = bib_library
      raise "Initialization error in #{self.class}. Missing bib library." if @bib_library.nil?
      super(uri)
      @uri = @uri+ "/record/#{bib_library}#{record_id}"
      # Format :xml parses response as a hash.
      # Eventually I'd like this to be the default since it raises exceptions for invalid XML.
      # self.class.format :xml
      # Format :html does no parsing, just passes back raw XML for parsing by client
      self.class.format :html
    end

    # Returns an XML string representation of a bib.  
    # Every method call refreshes the data from the underlying API.
    # Raises and exception if there are errors.
    def bib
      @response = self.class.get(@uri+ "?view=full")
      raise "Error getting bib from Aleph REST APIs. #{error}" unless error.nil?
      return @response
    end

    # Returns an array of items. Each item is represented as an HTTParty hash. 
    # Every method call refreshes the data from the underlying API.
    # Raises an exception if the response is not valid XML or there are errors.
    def items
      @items = []
      self.class.format :xml
      # Since we're parsing xml, this will raise an error
      # if the response isn't xml.
      @response = self.class.get(@uri+ "/items?view=full")
      self.class.format :html
      raise "Error getting items from Aleph REST APIs. #{error}" if not error.nil? or 
        @response.nil? or @response["get_item_list"].nil? or @response["get_item_list"]["items"].nil?
      item_list = @response["get_item_list"]["items"]["item"]
      @items.push(item_list) if item_list.instance_of?(Hash)
      item_list.each {|item|@items.push(item)} if item_list.instance_of?(Array)
      Rails.logger.warn("No items returned from Aleph in #{self.class}.") if @items.empty?
      return @items
    end

    # Returns an XML string representation of holdings 
    # Every method call refreshes the data from the underlying API.
    # Raises and exception if there are errors.
    def holdings
      @response = self.class.get(@uri+ "/holdings?view=full")
      raise "Error getting holdings from Aleph REST APIs. #{error}" unless error.nil?
      return @response
    end
  end
end