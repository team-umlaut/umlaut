require 'service_adaptors/opac'
class Voyager < Opac
  attr_reader :sru_url
  def init_bib_client
    return SruClient.new(self)
  end
  
  def init_holdings_client
    return self.init_bib_client
  end
end