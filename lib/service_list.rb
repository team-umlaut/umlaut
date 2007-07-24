class ServiceList
  private_class_method :new
  @@services = nil
  
  def self.get(name)
    @@services = YAML.load_file(RAILS_ROOT+"/config/services.yml") unless @@services

    if (@@services[name].nil?)
      raise NameError.new("No such service named #{name} has been loaded. Check config/services.yml", name)
    end
    if (@@services[name]["type"].nil?)
      raise "Service #{name} does not a type defined, and needs one. Check the config/services.yml file."
    end
    
    require 'service_adaptors/'+@@services[name]["type"].underscore
    
    className = @@services[name]["type"]
    classConst = Kernel.const_get(className)
    
    return classConst.new(@@services[name].merge({"id"=>name}))
  end
end