class RelevantSite < ActiveRecord::Base
  def self.is_relevant?(url)
    begin
      uri = URI.parse(url)
    rescue URI::InvalidURIError
      return false
    end  
    relevant = self.find_by_hostname(uri.host)
    return relevant if relevant
    return false    
  end
end
