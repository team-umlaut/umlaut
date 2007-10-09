require 'net/http'
require 'rexml/document'

# Pass in an ISBN and get back a list of related isbns
# as defined by the OCLC xisbn webservice at 
# http://www.oclc.org/research/projects/xisbn/
#
#   require 'xisbn'
#   include XISBN
#   isbns = xisbn('0-9745140-8-X')
#
# If you want to guard against timeouts pass in the number
# of seconds you don't want to wait longer than:
#
#   isbns = xisbn('0-94745140-8-X', :timeout => 1)
#
# If you want to use LibraryThing's xisbn service:
#
#   isbns = thing_isbn('0-9745140-8-X')

module XISBN
  require 'uri'
  @@oclc_uri = URI.parse('http://old-xisbn.oclc.org/webservices/xisbn')
  @@thing_uri = URI.parse('http://www.librarything.com/api/thingISBN')

  def xisbn(isbn, opts={})
    return get_isbns(@@oclc_uri, isbn, opts)
  end

  def thing_isbn(isbn, opts={})
    return get_isbns(@@thing_uri, isbn, opts)
  end

  private

  def get_isbns(uri, isbn, opts={})
    timeout = opts[:timeout] || 60
    redirects = opts[:redirects] || 10
    clean_isbn = isbn.gsub(/[^0-9X]/,'')

    # base case for http redirect recursion
    raise ArgumentError, 'Too many redirects' if redirects == 0

    http = Net::HTTP.new(uri.host)
    http.read_timeout = timeout
    http.open_timeout = timeout
    response = http.get("#{uri.path}/#{clean_isbn}")

    # follow HTTP redirects
    if response.kind_of?(Net::HTTPRedirection)
      return get_isbns(URI.parse(response['location']), isbn, 
        {:timeout => timeout, :redirects => (redirects-1)})
    end

    isbns = []
    doc = REXML::Document.new(response.body)
    doc.elements.each('idlist/isbn') {|e| isbns << e.text}
    return isbns
  end

end
