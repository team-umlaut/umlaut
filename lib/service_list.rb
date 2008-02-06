class ServiceList
  private_class_method :new
  @@services = nil

  # Returns a copy of a Service object, intialized with values
  # from services.yaml, matching definition given by input param 'name'
  # Does NOT create a new copy with every call; instead lazy-loads once and
  # caches. 
  def self.get(name)
    @@services = YAML.load_file(RAILS_ROOT+"/config/umlaut_config/services.yml") unless @@services

    if (@@services[name].nil?)
      raise NameError.new("No such service named #{name} has been loaded. Check config/umlaut_config/services.yml", name)
    end
    if (@@services[name]["type"].nil?)
      raise "Service #{name} does not a type defined, and needs one. Check the config/umlaut_config/services.yml file."
    end
    
    require_dependency 'service_adaptors/'+@@services[name]["type"].underscore
    
    className = @@services[name]["type"]
    classConst = Kernel.const_get(className)
    
    return classConst.new(@@services[name].merge({"id"=>name}))
  end

  def self.require_service_class(service_name)
    require_dependency 'service_adaptors/'+service_name.underscore
  end

  @@services_yml_ctime = nil
  @@services_yml_ctime_checked = nil
  # pass in a time. Return: Has the services.yml been changed since then?
  # It might take 60 seconds to notice the services.yml has been changed,
  # because we do cache last change time for 60s.
  # This is currently used by collection, so services stored in session
  # will be refreshed when neccesary. It is NOT yet used by ServiceList
  # itself to fresh it's cached services; doing that in a thread-safe
  # way is tricky. Just restart the mongrels to refresh cached services.
  def self.stale_services?(time)
  
    # Instead of examining the file ctime on _every_ request, we cache
    # for a minute.
    if ( @@services_yml_ctime.nil? || @@services_yml_ctime_checked < Time.now - 60 )
      path = File.join( RAILS_ROOT, "config", "umlaut_config", "services.yml")
      @@services_yml_ctime = File.new(path).ctime
      @@services_yml_ctime_checked = Time.now
    end    
    
    return time.nil? || @@services_yml_ctime > time
  end

  
end