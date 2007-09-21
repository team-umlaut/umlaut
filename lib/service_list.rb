class ServiceList
  private_class_method :new
  @@services = nil

  # Creates a new copy of a Service object, intialized with values
  # from services.yaml, matching definition given by input param 'name'
  def self.get(name)
    @@services = YAML.load_file(RAILS_ROOT+"/config/services.yml") unless @@services

    if (@@services[name].nil?)
      raise NameError.new("No such service named #{name} has been loaded. Check config/services.yml", name)
    end
    if (@@services[name]["type"].nil?)
      raise "Service #{name} does not a type defined, and needs one. Check the config/services.yml file."
    end
    
    require_dependency 'service_adaptors/'+@@services[name]["type"].underscore
    
    className = @@services[name]["type"]
    classConst = Kernel.const_get(className)
    
    return classConst.new(@@services[name].merge({"id"=>name}))
  end

  def self.require_service_class(service_name)
    require_dependency 'service_adaptors/'+service_name.underscore
  end

end