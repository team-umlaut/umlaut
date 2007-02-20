class Permalink < ActiveRecord::Base
  belongs_to :referent
  def tag_uri
    require "socket"
    host = Socket.gethostname  
    return 'tag:'+host+','+self.created_on.year.to_s+'-'+self.created_on.month.to_s+'-'+self.created_on.day.to_s+':'+self.id.to_s
  end
end
