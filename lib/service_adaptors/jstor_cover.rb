# JStor covers are freely available at a predictable URL. These are in
# the "fsearch-sandbox" -- not sure if this is going to break in the future. 
#
# I'm not entirely sure if JStor actually would like it if we were using them
# like this, but as a publisher they hopefully want to help customers advertise
# journals with covers. 
class JstorCover < Service
  require 'open-uri'
  
  def service_types_generated
    return [ServiceTypeValue[:cover_image]]
  end

  def initialize(config)
    @base_url = "http://fsearch-sandbox.jstor.org/graphics/thumbs/"
    @display_name = "JStor Journal Covers"
    
    super(config)
  end
  
  def handle(request)
    issn = request.referent.issn

    # We need an ISSN
    return request.dispatched(self, true) unless issn 

    # No hyphens please
    issn = issn.gsub(/[^0-9X]/, '')
    
    check_url = @base_url + issn + '.gif'

    # does it exist?
    if ( url_resolves(check_url)   )
       request.add_service_response(:service => self,
                                    :service_type_value => ServiceTypeValue[:cover_image] ,
                                    :url => check_url, 
                                    :size => "medium" )
    end   
    
    return request.dispatched(self, true)
  end

  def url_resolves(url)
    uri_obj = URI.parse(url)
    response = Net::HTTP.start(uri_obj.host, uri_obj.port) {|http|
      http.head(uri_obj.request_uri)
    }
    if (response.kind_of?( Net::HTTPSuccess  ))
      return true
    elsif ( response.kind_of?(Net::HTTPNotFound))
      return false
    else
      # unexpected condition, raise
      response.value
    end

    
  end
  
end
