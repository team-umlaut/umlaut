# using has_enumerated :service_type_value
# so: st.service_type_value = ServiceTypeValue[:fulltext]
#   same thing as
#     st.service_type_value = 'fulltext'
#   either way:
#     st.service_type_value     ==> ServiceTypeValue object with name 'fulltext'
class ServiceType < ActiveRecord::Base
  belongs_to :request
  belongs_to :service_response
  # Special relationship to our acts_as_enumerated ServiceTypeValue
  has_enumerated :service_type_value

  # convenience method to skip accross relationships to
  # Service#view_data_from_service_type, since
  # if often must be done. Returns a hash or hash-like object with
  # properties for the service response. 
  def view_data
    service_response.service.view_data_from_service_type( self )
  end
  alias  :view_data_from_service_type :view_data

  # Should take a ServiceTypeValue object, but for backwards compatibilty
  # if it's a string or symbol, we'll magically convert it the right
  # ServiceTypeValue. acts_as_enumerated is neat!
  def service_type=(value)
    # pass it on to the new one
    self.service_type_value = value
    # plus do it the old way
    write_attribute(:service_type, value)
  end
end
