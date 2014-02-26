require 'isbn_link'

# Blind (not pre-checked for hits) link to compare prices
# at AllBookstores.com
# -- because that site seemed good, includes shipping prices, has decent UX, 
# and includes independent bookstores like Powell's and The Strand. 
#
# subclasses IsbnLink
class AllBooksDotCom < IsbnLink
  def initialize(config)    
    super(config)

    @display_text   ||= "Compare online prices"
    @display_name   ||= "AllBookstores.com"
    @link_template  ||= "http://www.allbookstores.com/book/compare/%s"
  end
end