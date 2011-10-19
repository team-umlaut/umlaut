require 'singleton'
# This guy is a singleton, get one with ServiceList.instance
class ServiceList
  include Singleton # call ServiceList.instance to get the singleton instance.
  @@services_yaml_path = Rails.root + "config/umlaut_config/services.yml"

  def initialize
    @services = nil
  end

  # Pretty much only used for testing
  def self.yaml_path=(path)
    @@services_yaml_path = path
    self.instance.reload
  end

  
  # Returns a NEW copy of a Service object, intialized with values
  # from services.yaml, matching definition given by input param 'name', the
  # name/id a service is referred to by in services.yml
  def instantiate!(name, request)
    if (cached_service_data[name].nil?)
      raise NameError.new("No such service named #{name} has been loaded. Check config/umlaut_config/services.yml", name)
    end
    if (cached_service_data[name]["type"].nil?)
      raise "Service #{name} does not a type defined, and needs one. Check the config/umlaut_config/services.yml file."
    end
        
    className = cached_service_data[name]["type"]
    classConst = Kernel.const_get(className)
    service = classConst.new(self.definition(name))
    service.request = request

    return service
  end

  def definition(name)
    return cached_service_data[name]      
  end

  # call cached_service_data, but don't return the results, they're private man!
  def reload
    @services = nil
    cached_service_data
    true
  end
  
  protected
  
  def cached_service_data
    unless @services
      @services = YAML.load_file(@@services_yaml_path)
      # Add 'service_id' keys to all the hashes by the id they were named in the hash.
      @services.each_pair do |key, value|
        value['service_id'] = key if value && key
      end
    end
    return @services    
  end
  
end