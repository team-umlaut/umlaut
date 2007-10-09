require 'net/http'
require 'rexml/document'
module ResolverRegistry
  class Client

    def initialize(opts={})    
      @timeout = opts.fetch(:timeout, 60)
    end

    # get a ResolverRegistry::Institition object for a given IP address
    # theoretically more than one can be returned for a given IP
    # address, so if you want all of them use lookup_all. If there
    # was no match Nil will be returned.
    def lookup(ip)
      return lookup_all(ip)[0]
    end
  
    # similar to lookup() only it returns a list of all matching 
    # ResolverRegistry::Instition objects for a given IP address. If
    # there were no matches you will get back an empty list.
    def lookup_all(ip)
      Net::HTTP.start('worldcatlibraries.org', 80) do |http|
        http.read_timeout = @timeout
        http.open_timeout = @timeout 
        xml = http.get("/registry/lookup?IP=#{ip}").body
        response = ResolverRegistry::Response.new(xml)
        return response.institutions
      end
      return []
    end

  end
end
