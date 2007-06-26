class ServiceList
  private_class_method :new
  @@services = nil
  
  def self.get(name)
    @@services = YAML.load_file(RAILS_ROOT+"/config/services.yml") unless @@services   
    require 'service_adaptors/'+@@services[name]["type"].underscore   
    return Kernel.const_get(@@services[name]["type"]).new(@@services[name].merge({"id"=>name}))
  end  
end