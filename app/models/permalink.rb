# attribute context_obj_serialized has an XML OpenURL ContextObject sufficient to restore
# the original request and resolve the permalink. A link to a referent is
# also stored. But the referent may be purged, so self.referent may be null.
# The serialized contextobject will still be there. 
class Permalink < ActiveRecord::Base
  belongs_to :referent

  # You should create Permalinks with this. Pass in a referent and referrer
  #. Will save  permalink to db
  def self.new_with_values!(rft, rfr_id)
    permalink = Permalink.new        

    permalink.referent = rft
    permalink.orig_rfr_id = rfr_id
    
    permalink.context_obj_serialized = permalink.referent.to_context_object.xml

    permalink.save!
    
    return permalink
  end


  # Takes the XML stored in self.context_obj_serialized, and turns it back
  # into an OpenURL ContextObject
  def restore_context_object
    return OpenURL::ContextObject.new_from_xml(self.context_obj_serialized)
  end
end
