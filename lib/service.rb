# Services are defined from the config/Services.yml file.
# hey should have the following properties
# id : unique internal string for the service, unique in yml file
# display_name : user displayable string
# url : A base url of some kind used by specific service
# type : Class name of class found in lib/service_adaptors to be used for logic
# priority: 0-9 (foreground) or a-z (background) for order of service operation
#
#  Specific service_adaptor classes may have specific addtional configuration,
#  commonly including 'password' or 'api_key'. 

class Service
  attr_reader :priority, :id, :url
  def initialize(config)
    config.each do | key, val |
      self.instance_variable_set(('@'+key).to_sym, val)
    end
  end

  def display_name
    # If no display_name is set, default to the id string. Not a good idea,
    # but hey. 
    return @display_name ||= self.id    
  end


  # Pass this method a ServiceType object, it will return a hash of parsed
  # display values, for the view. Implementation is usually in sub-class, by
  # means of a set of methods "to_[service type name]" implemented in sub-class
  #. parseResponse will find those. Subclasses will not generally override
  # view_data_from_service_type. 
  def view_data_from_service_type(service_type_obj)
    service_type_code = service_type_obj.service_type
    service_response = service_type_obj.service_response
    begin
      # try to call a method named "to_#{service_type_code}", implemented by sub-class
      self.send("to_#{service_type_code}", service_response)
    rescue NoMethodError 
    # No to_#{response_type} method? How about the catch-all method?
    # If not implemented in sub-class, we have a VERY basic
    # default implementation in this class. 
        self.send("response_to_view_data", service_response)
    end
  end

  # Default implementation to take a ServiceResponse and parse
  # into a hash of values useful to the view. Usually sub-classes
  # will over-ride, but this is a nice generic basic implementation. 
  def response_to_view_data(service_response)
      # That's it, pretty simple.
      return { :display_text => service_response.response_key }
  end
  
end
