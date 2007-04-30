class IrrelevantSite < ActiveRecord::Base
  require 'uri'
  def self.is_irrelevant?(url)
    begin
      uri = URI.parse(url)
    rescue URI::InvalidURIError
      return true
    end
    irrelevant = self.find_by_hostname(uri.host)
    return true if irrelevant
    return false
  end
end
