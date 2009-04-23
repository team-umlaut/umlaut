# Ulrich's provides journal cover images that are _publically_ available, at
# predictable urls based on issn. Not sure if this is intentional. But as
# an ulrich's subscriber, I feel fine using it. If my insitution was not
# an ulrich's subscriber, I probably wouldn't use this service. 
class UlrichsCover < Service
  require 'open-uri'
  
  def service_types_generated
    return [ServiceTypeValue[:cover_image]]
  end

  def initialize(config)
    @base_url = "http://images.serialssolutions.com/ulrichs/"
    
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
