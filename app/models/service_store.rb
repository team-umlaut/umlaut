# Loads Service definitions from Rails.root/config/umlaut_services.yml
# instantiates services from definitions, by id.
#
# It's terrible we need to do this globally like this, but
# too hard to back out of legacy design now. 
class ServiceStore
  
  # Returns complete hash loaded from services.yml
  def self.config
    # cache hash loaded from YAML, ensure it has the keys we expect. 
    unless defined? @@services_config_list
      yaml_path = File.expand_path("config/umlaut_services.yml", Rails.root)
      if File.exists? yaml_path
        @@services_config_list = YAML::load(File.open( yaml_path ))        
      else
        @@services_config_list = {}
      end
      @@services_config_list["default"] ||= {}
      @@services_config_list["default"]["services"] ||= {}
    end
    return @@services_config_list
  end
  
  # Returns hash keyed by unique service name, value service definition
  # hash. 
  def self.service_definitions
    unless defined? @@service_definitions
      @@service_definitions = {}
      config.each_pair do |group_name, group|
        @@service_definitions.merge!(  group["services"]  ) if group["services"]
      end
    end
    return @@service_definitions
  end
  
  def self.service_definition_for(service_id)
    return service_definitions[service_id]
  end
  
  # pass in string unique key OR a service definition hash, 
  # and a current UmlautRequest.
  # get back instantiated Service object. 
  def self.instantiate_service!(service, request)
    definition = service.kind_of?(Hash) ? service : service_definition_for(service.to_s)
        
    if definition.nil?
      raise "Service '#{service}'' does not exist in umlaut-services.yml"
    end
    
    className = definition["type"] || definition["service_id"]
    classConst = Kernel.const_get(className)
    service = classConst.new(definition)
    service.request = request

    return service    
  end
  
  
end
