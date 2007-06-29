class ServiceList
  private_class_method :new
  @@services = nil
  
  def self.get(name)
    @@services = YAML.load_file(RAILS_ROOT+"/config/services.yml") unless @@services

    if (@@services[name].nil?)
      raise NameError.new("No such service named #{name} has been loaded. Check config/services.yml", name)
    end
    
    require 'service_adaptors/'+@@services[name]["type"].underscore
    
    className = @@services[name]["type"]
    classConst = Kernel.const_get(className)
    
    return classConst.new(@@services[name].merge({"id"=>name}))
  end
end