require 'yaml'

# This model is the actual list of valid service types. Since it uses the
# acts_as_enumerated plugin, you can in code just do something like
# ServiceTypeValue[:fulltext], to get the relevant ServiceTypeValue
# in an efficient and easy way.
#
# ServiceType values loaded from distro yaml file overlayed with local yaml file. 
#
# ServiceTypeValue's also have displable strings, stored in the
# display_name attribute.
#
class ServiceTypeValue 
  attr_accessor :display_name, :name, :display_name_plural, :id
  
  @@distro_conf_file = File.join(RAILS_ROOT, "db", "orig_fixed_data", "service_type_values.yml")
  @@local_conf_file = File.join(RAILS_ROOT, "config", "umlaut_config", "local_service_type_values.yml")

  
  def self.all
    reload_services! unless defined? @@services
    @@services
  end
  
  #Lookup a ServiceTypeValue by unique name, such as :fulltext  
  def self.[](name) 
    found = all.find {|s| s.name == name.to_s}
    found or raise Exception.new("No ServiceTypeValue with unique name #{name}")
  end
  
  # hash-like [] access
  def [](key)
    send("#{key}")
  end
  
  # hash like []= setting
  def []=(key, value)
    send("#{key}=", value)
  end
  
    
  
  def display_name_pluralize
    return self.display_name_plural || self.display_name.pluralize
  end
  
  # Reload fresh list of services from config yaml files, both distro and local. 
  def self.reload_services!
    service_type_values = YAML.load_file( @@distro_conf_file )
    local_overrides = if File.exists?( @@local_conf_file )
              YAML.load_file(@@local_conf_file) 
            else
              nil
            end
            
    # Merge in the params for each service type with possible
    # existing params.
    if ( local_overrides )
      local_overrides.each do |name, params|
        if ( service_type_values[name])
          service_type_values[name].merge!(params )
        else
          service_type_values[name] = params
        end
      end
    end
    
    @@services = 
      service_type_values.collect do |name, hash|                 
        value_obj = ServiceTypeValue.new
        # Add the YAML label to the hash, for ease of lookup
        value_obj['name'] = name.to_s
        hash.each do |key, value|
          value_obj[key] = value
        end  
        value_obj
      end    
 
  end


  
end
