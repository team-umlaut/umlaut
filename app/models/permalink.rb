# attribute context_obj_serialized has an XML OpenURL ContextObject sufficient to restore
# the original request and resolve the permalink. A link to a referent is
# also stored. But the referent may be purged, so self.referent may be null.
# The serialized contextobject will still be there. 
class Permalink < ActiveRecord::Base
  belongs_to :referent

  # You should create Permalinks with this. Pass in a referent. Will save
  # permalink to db, and create a ReferentValue for an identifier with
  # tag-uri based on the permalink. 
  def self.new_with_referent!(rft)
    permalink = Permalink.new
    permalink.referent = rft
    
    permalink.context_obj_serialized = permalink.referent.to_context_object.xml

    permalink.save!

    permalink.add_tag_uri!(rft)
    
    return permalink
  end

  # Adds a ReferentValue to argument representing identifier with tag-uri for
  # self. ReferentValue does end up saved. 
  def add_tag_uri!(referent)
    val = ReferentValue.new
    val.key_name = 'identifier'
    val.value = self.tag_uri
    val.normalized_value = val.value
    referent.referent_values << val
  end
  
  def tag_uri
    require "socket"
    host = Socket.gethostname  
    return 'tag:'+host+','+self.created_on.year.to_s+'-'+self.created_on.month.to_s+'-'+self.created_on.day.to_s+':'+self.id.to_s
  end

  # Takes the XML stored in self.context_obj_serialized, and turns it back
  # into an OpenURL ContextObject
  def restore_context_object
    return OpenURL::ContextObject.new_from_xml(self.context_obj_serialized)
  end
end
