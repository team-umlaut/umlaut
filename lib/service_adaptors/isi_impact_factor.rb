
class IsiImpactFactor < Service
  require 'timeout'
  require 'open-uri'
  include MetadataHelper
  
  def service_types_generated
    return [ServiceTypeValue['highlighted_link']]
  end

  def initialize(config)
    @timeout = 7
    @display_text = "Journal Impact Factor"
    @display_name = "ISI Journal Citation Reports"
    @host = "admin-apps.isiknowledge.com"
    @base_path = "/JCR/JCR?PointOfEntry=Impact&issn="
    super(config)
  end

  def handle(umlaut_request)
    
    issn = get_identifier(:urn, "issn", umlaut_request.referent)

    
    # No isbn, nothing we can do. 
    return umlaut_request.dispatched(self, true) if issn.blank?
    
    response = do_request(issn)

    # Sadly, reduced to a screen scrape to see if we got a hit. 
    unless response.read =~ /The ISSN number does not exist/i
      create_service_response(umlaut_request, issn)
    end
    
    return umlaut_request.dispatched(self, true)
  end

  def path(issn)
    return @base_path + CGI.escape(issn)
  end
  
  def do_request(issn)
    
     Timeout::timeout(@timeout) do
       return open("http://" + @host + path(issn))
     end

     return response
  end

  def create_service_response(umlaut_request, issn)
      url = "http://" + @host + path(issn)
    
      umlaut_request.add_service_response( {:service=>self, :url=> url, :display_text=> @display_text}, [ServiceTypeValue[:highlighted_link]])
  end
  
end
