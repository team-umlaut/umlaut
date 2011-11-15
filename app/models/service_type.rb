# st.service_type_value = ServiceTypeValue[:fulltext]
#   same thing as
#     st.service_type_value = 'fulltext'
#   either way:
#     st.service_type_value     ==> ServiceTypeValue object with name 'fulltext'
class ServiceType < ActiveRecord::Base
  belongs_to :request
  belongs_to :service_response
  
  # convenience method to skip accross relationships to
  # Service#view_data_from_service_type, since
  # if often must be done. Returns a hash or hash-like object with
  # properties for the service response. 
  def view_data
    service_response.service.view_data_from_service_type( self )
  end
  alias  :view_data_from_service_type :view_data

  # Should take a ServiceTypeValue object, or symbol name of
  # ServiceTypeValue object. 
  def service_type_value=(value)
    value = ServiceTypeValue[value] unless value.kind_of?(ServiceTypeValue)        
    self.service_type_value_name = value.name   
  end
  def service_type_value
    ServiceTypeValue[self.service_type_value_name]
  end
end
