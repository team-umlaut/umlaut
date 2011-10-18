# Link to BookFinder.com to compare online new and used prices for a book.
# Requires an ISBN.
# Does not a pre-check, just generates the link blind, but I think almost any
# ISBN will get results on BookFinder.
class BookFinder < Service
  require 'isbn'
  
  def initialize(config)
    @display_text = "Compare online prices"
    @display_name = "BookFinder.com"
    # %s is where the ISBN goes
    @url_template = 'http://www.bookfinder.com/search/?isbn=%s&st=xl&ac=qr'

    super(config)
  end

  def service_types_generated
    return [ServiceTypeValue['highlighted_link']]
  end

  def handle(umlaut_request)
    isbn = umlaut_request.referent.isbn

    # Unless we have a valid isbn, give up
    return request.dispatched(self, true) unless isbn && ISBN.valid?(isbn)

    # Okay, make a link
    url = @url_template.sub('%s', isbn)

    umlaut_request.add_service_response({:service=>self, :url=> url, :display_text=> @display_text, :service_type_value => :highlighted_link})

    return request.dispatched(self, true)    
  end
  
end
