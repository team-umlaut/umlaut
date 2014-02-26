require 'isbn'

# A simple service to generate a blind link (NOT pre-checked for hits, just
# blindly created from a template) out to a service based on ISBN. 
#
# May likely be sub-classed for specific services (see AllBooks.com),
# which set default values. 
#
# * :link_template. => String where "%s" will be replaced with ISBN
# * :display_name 
# * :dispaly_text. Such as "Compare online prices
# * :isbn_normalize. Default nil, set to :ten or :thirteen if you need to normalize
#     ISBN before substituting in :link_template. 
class IsbnLink < Service
  include MetadataHelper
      
  def service_types_generated
    return [ServiceTypeValue['highlighted_link']]
  end

  def initialize(config)    
    @display_text   = "Compare online prices"
    @isbn_normalize = nil
    
    super(config)
  end

  def handle(umlaut_request)
    
    isbn = get_isbn(umlaut_request.referent)
    
    # No isbn, nothing we can do. 
    return umlaut_request.dispatched(self, true) if isbn.blank?

    # invalid isbn? forget it. 
    return umlaut_request.dispatched(self, true) unless ISBN.valid?(isbn)

    if @isbn_normalize == :ten
      isbn = ISBN.ten(isbn)    
    elsif @isbn_normalize == :thirteen
      isbn = ISBN.thirteen(isbn)
    end
    
    # Add the link
    link = @link_template.gsub("%s", isbn)
    
    umlaut_request.add_service_response(
      :service=>self, 
      :url=> link, 
      :display_text=> @display_text,
      :service_type_value => ServiceTypeValue[:highlighted_link]
    )

    return umlaut_request.dispatched(self, true)
  end
    
end
