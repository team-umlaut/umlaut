require 'uri'
require 'cgi'
require 'net/http'
require 'rexml/document'

module SRU

  # A client for issuing requests to a particular SRU server.
  # SRU is a RESTlike information retrieval protocol detailed at
  # http://www.loc.gov/standards/sru/
  #
  #  require 'sru'
  #
  #  client = SRU::Client.new 'http://sru.example.com'
  #
  #  # fetch a SRU::ExplainResponse object from the server
  #  explain = client.explain
  #
  #  # issue a search and get back a SRU::SearchRetrieveResponse object 
  #  # which serves as an iterator 
  #  records = client.search_retrieve 'rosetta stone', :maximumRecords => 5
  #  records.each {|record| puts record}
  #
  #  # issue a scan request and print out each term
  #  client.scan('king tut', :maximumTerms => 12).each {|term| puts term}
  
  class Client

    # creates a client object which will automatically perform an
    # explain request to determine the version to be used in 
    # subsequent requests.
    
    def initialize(base)
      @server = URI.parse base

      # stash this away for future requests
      @version = self.explain.version
    end


    # Send an explain request to the SRU server and return a 
    # SRU::ExplainResponse object.
    #
    # client = SRU::Client.new 'http://sru.example.com'
    # explain = client.explain
    
    def explain
      doc = get_doc(:operation => 'explain')
      return ExplainResponse.new(doc)
    end


    # Send a searchRetrieve request to the SRU server and return
    # a SRU::SearchResponse object. The first argument is the required 
    # query option. Any remaining searchRetrieve options can be passed 
    # as an optional second argument. 
    # 
    #   client = SRU::Client.new 'http://example.com/sru'
    #   response = client.search_retrieve 'mark twain', maximumRecords => 1
    
    def search_retrieve(query, options={})
      options[:query] = query
      options[:operation] = 'searchRetrieve'
      options[:maximumRecords] = 10 unless options.has_key? :maximumRecords
      doc = get_doc(options)
      return SearchResponse.new(doc)
    end


    # Send a scan request to the SRU server and return a SRU::ScanResponse
    # object. You must supply the first parameter which is the searchClause.
    # Other SRU options can be sent in a hash as the seond argument.
    #
    #   scan_response = client.scan 'title', :maximumTerms => 5
   
    def scan(clause, options={})
      options[:scanClause] = clause
      options[:operation] = 'scan'
      options[:maximumTerms] = 5 unless options.has_key? :maximumTerms
      doc = get_doc(options)
      return ScanResponse.new(doc)
    end

    private

    # helper to fetch xml responses from the sru server
    # given a set of options
   
    def get_doc(hash)
      # all requests get a version
      hash[:version] = @version 

      # don't want to monkey with the original
      uri = @server.clone

      # no ruby class for building a query string!?!?
      # probably just wasn't looking in the right place
      parts = hash.entries.map { |entry| 
        "#{entry[0]}=#{CGI.escape(entry[1].to_s)}"
      }
      uri.query = parts.join('&')

      # fetch the xml and build/return a document object from it
      begin
        xml = Net::HTTP.get(uri)
        return REXML::Document.new(xml)
      rescue 
        raise SRU::Exception, "exception during SRU operation", caller
      end
    end
  end
end
