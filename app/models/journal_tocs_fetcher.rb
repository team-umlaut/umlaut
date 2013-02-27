require 'nokogiri'
require 'httpclient'
require 'httpclient/include_client'

require 'bento_search'

require 'htmlentities'

# Initialize with an ISSN, and a registered email address (used as api key)
#
#    JournalTocsFetcher.new("12345678", :registered_email => "nobody@example.com")
#
# register an email address at: http://www.journaltocs.ac.uk/index.php?action=register
#
# Fetches with a class-level HTTPClient
class JournalTocsFetcher
    extend HTTPClient::IncludeClient
    include_http_client
    
    include ActionView::Helpers::SanitizeHelper # strip_tags
    
    attr_accessor :issn, :configuration
    
    def initialize(arg_issn, arg_config = {})
      self.issn = arg_issn.to_s
      
      self.configuration = arg_config.reverse_merge(
        :base_url => 'http://www.journaltocs.ac.uk/api',
        # email used as example in journaltocs docs, works for now
        :registered_email => 'macleod.roddy@gmail.com'
      )      
    end
  
    
    
    # return a nokogiri document of journal Tocs results
    #
    # May raise JournalTocsFetcher::FetchError on error (bad baseURL, bad API key, 
    # error response from journaltocs)
    def fetch_xml     
      
      xml = 
        begin
          response = http_client.get(request_url)    
          
          unless response.ok?
            raise FetchError.new("#{request_url}: returns #{response.status} response")
          end
          
          Nokogiri::XML(response.body)
        rescue SocketError => e
          raise FetchError.new("#{request_url}: #{e.inspect}")
        end
      

      
      # There's no good way to tell we got an error from unregistered email
      # or other usage problem except sniffing the XML to try and notice
      # it's giving us a usage message. 
      if ( xml.xpath("./rdf:RDF/rss:item", xml_ns).length == 1 &&
           xml.at_xpath("./rdf:RDF/rss:item/rss:link", xml_ns).try(:text) == "http://www.journaltocs.ac.uk/develop.php" )
        raise FetchError.new("Usage error on api call, missing registered email? #{request_url}")
      end      
      
      return xml
    end
    
    # returns an array of BentoSearch::ResultItem objects, representing
    # items. 
    def items      
      BentoSearch::Results.new.concat(      
        xml.xpath("./rdf:RDF/rss:item", xml_ns).collect do |node|        
          item = BentoSearch::ResultItem.new
          
          item.format = "Article"
          
          item.issn   = self.issn # one we searched with, we know that!
                  
          item.title  = xml_text(node, "rss:title")
          item.link   = xml_text(node, "rss:link")
                          
          item.publisher      = xml_text(node, "prism:publisher") || xml_text(node, "dc:publisher") 
          item.source_title   = xml_text(node, "prism:PublicationName")
          item.volume         = xml_text(node, "prism:volume")
          item.issue          = xml_text(node, "prism:number")
          item.start_page     = xml_text(node, "prism:startingPage")
          item.end_page       = xml_text(node, "prism:endingPage")
          
          # Look for something that looks like a DOI in dc:identifier        
          node.xpath("dc:identifier").each do |id_node| 
            if id_node.text =~ /\ADOI (.*)\Z/
              item.doi = $1
              break
            end
          end
          
          # authors?
          node.xpath("dc:creator", xml_ns).each do |creator_node|
            name = creator_node.text
            name.strip!
            
            # author names in RSS seem to often have HTML entities,
            # un-encode them to literals. 
            name = HTMLEntities.new.decode(name)
            
            
            item.authors << BentoSearch::Author.new(:display => name)
          end
          
          # Date is weird and various formatted, we do our best to
          # look for yyyy-mm-dd at the beginning of either prism:coverDate or
          # dc:date or prism:publicationDate 
          date_node = xml_text(node, "prism:coverDate") || xml_text(node, "dc:date") || xml_text(node, "prism:publicationDate")
          if date_node && date_node =~ /\A(\d\d\d\d-\d\d-\d\d)/ 
            item.publication_date = Date.strptime( $1, "%Y-%m-%d")
          end
          
          # abstract, we need to strip possible HTML tags (sometimes they're
          # there, sometimes not). 
          item.abstract   = xml_text(node, "rss:description").try do |text|
            strip_tags(text)
          end
          
          item
        end
      )
    end
    
    # just a convenience method
    def xml_text(node, xpath)
      node.at_xpath(xpath, xml_ns).try(:text)
    end
    
    # calls fetch_xml, but caches response. Can raise FetchError from fetch_xml,
    # see fetch_xml
    def xml
      @xml ||= fetch_xml 
    end
  
    def xml_ns
      { "rdf" => "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
        "rss" => "http://purl.org/rss/1.0/",
        "prism"=>"http://prismstandard.org/namespaces/1.2/basic/", 
        "dc"=>"http://purl.org/dc/elements/1.1/",
        "mn"=>"http://usefulinc.com/rss/manifest/",
        "content"=>"http://purl.org/rss/1.0/modules/content/" 
      }
    end
    
    def request_url
      "#{configuration[:base_url]}/journals/#{issn}?output=articles&user=#{CGI.escape configuration[:registered_email]}"
    end
    
    class FetchError < ::StandardError ; end
   
    
  
end
