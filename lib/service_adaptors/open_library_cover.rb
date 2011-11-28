# Looks for cover images from OpenLibrary Cover API.
# Lookig up covers in OL can require multiple HTTP requests, one for each
# identifier, which can sometimes lead to slowness. 
# OL also doesn't have great cover image coverage.  So if you have access to
# Amazon or Google covers, you probably don't need this service. 
class OpenLibraryCover < Service
  require 'net/http'
  
  def service_types_generated
    return [ServiceTypeValue[:cover_image]]
  end

  def initialize(config)
    @base_url = "http://covers.openlibrary.org/b/"    
    @size = "medium" # "small", "medium" or "large"
    super(config)
  end

  def handle(request)
    ids = {
      :isbn => request.referent.isbn,
      :oclc => request.referent.oclcnum,
      :lccn => request.referent.lccn
    }
    ids.delete_if {|k,v| v.blank?}

    # Return if we don't have any identifiers
    return request.dispatched(self, true) unless ids.size > 0

    # What order is best for trying first?
    [:isbn, :oclc, :lccn].each do |type|
      next unless ids[type]

      uri = cover_uri(type, ids[type] )
      s_time = Time.now
      response = Net::HTTP.get_response(URI.parse(uri))
      Rails.logger.debug("#{@id}: #{Time.now - s_time}s to lookup #{uri}")
      
      if response.kind_of?( Net::HTTPNotFound  )
        # OL has no cover      
        next
      end

      unless response.kind_of?( Net::HTTPSuccess  )
        # unexpected response
        Rails.logger.error("#{@id}: Error in HTTP response when requesting #{uri},  #{response.inspect}")
      end

      # Got this far, we've got a response.
      request.add_service_response(  
        :service => self,
        :display_text => "Cover Image",
        :size => "medium",
        :url => uri,
        :service_type_value => :cover_image
      )
      break
    end

    return request.dispatched(self, true)
  end

  def cover_uri(type, id)
    @base_url + type.to_s + "/" + id.to_s + "-" + @size[0,1].upcase + ".jpg?default=false"
  end

  
end
