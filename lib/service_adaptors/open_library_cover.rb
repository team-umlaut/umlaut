# Looks for cover images from OpenLibrary Cover API. 

class OpenLibraryCover < Service
  require 'net/http'
  
  def service_types_generated
    return [ServiceTypeValue[:cover_image]]
  end

  def initialize(config)
    @base_url = "http://covers.openlibrary.org/b/"
    @size = "M"
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
      response = Net::HTTP.get_response(URI.parse(uri))

      
      if response.kind_of?( Net::HTTPNotFound  )
        # OL has no cover      
        next
      end

      unless response.kind_of?( Net::HTTPSuccess  )
        # unexpected response
        RAILS_DEFAULT_LOGGER.error("#{@id}: Error in HTTP response when requesting #{uri},  #{response.inspect}")
      end

      # Got this far, we've got a response.
      request.add_service_response(  
        :service => self,
        :display_text => "Cover Image",
        :size => "medium",
        :url => uri
      )
      break
    end

    return request.dispatched(self, true)
  end

  def cover_uri(type, id)
    @base_url + type.to_s + "/" + id.to_s + "-" + @size + ".jpg?default=false"
  end

  
end
