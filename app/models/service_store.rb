# A ServiceStore is a collection of umlaut service definitions, with identifiers. 
#
# There is one default global one that is typically used; originally this
# was all neccesarily global state, but we refactored to be an actual object,
# although there's still a default global one used, with class methods
# that delegate to it, for backwards compat and convenience. 
#
# By default, a ServiceStore loads service definitions from 
# Rails.root/config/umlaut_services.yml . Although in testing,
# or for future architectural expansion, services can be manually supplied
# instead. 
#
# A ServiceStore instantiates services from definitions, by id, 
# ServiceStore.instantiate_service!("our_sfx")
#
# A ServiceStore's cached service definitions can be reset, useful in
# testing:  ServiceStore.reset!
#
# They'll then be lazily reloaded on next access, unless manually set. 
class ServiceStore
  @@global_service_store = ServiceStore.new
  def self.global_service_store
    @@global_service_store
  end

  # certain class methods all default to global default ServiceStore,
  # for global ServiceStore.  For convenience, and backwards-compat. 
  [ :config, :"config=", :service_definitions, :service_definition_for, 
    :'instantiate_service!', :'reset!' ].each do |method|
    self.define_singleton_method(method) do |*args|      
      global_service_store.send(method, *args)
    end
  end


  # Returns complete hash loaded from services.yml
  def config
    # cache hash loaded from YAML, ensure it has the keys we expect.
    unless defined? @services_config_list
      yaml_path = File.expand_path("config/umlaut_services.yml", Rails.root)
      @services_config_list = (File.exists? yaml_path) ? YAML::load(File.open(yaml_path)) : {}
      @services_config_list["default"] ||= {}
      @services_config_list["default"]["services"] ||= {}
    end
    return @services_config_list
  end

  # Manually set a config hash, as would normally be found serialized
  # in config/umlaut_services.yml.  Useful in testing. All keys
  # should be strings!! 
  #
  # Needs to have the somewhat cumbersome expected structure:
  # ["default"]["services"] => { "service_id" => definition_hash }  
  def config=(hash)
    reset!
    @services_config_list = hash
  end

  # Returns hash keyed by unique service name, value service definition
  # hash.
  def service_definitions
    unless defined? @service_definitions
      @service_definitions = {}
      config.each_pair do |group_name, group|
        if group["services"]
          # Add the group name to each service
          # in the group
          group["services"].each_pair do |service_id, service|
            service["group"] = group_name
          end
          # Merge the group's services into the service definitions.
          @service_definitions.merge!(  group["services"]  )
        end
      end
      # set service_id key in each based on hash key
      @service_definitions.each_pair do |key, hash|
        hash["service_id"] =  key
      end
    end
    return @service_definitions
  end

  # Reset cached service definitions. They'll be lazily loaded when asked for, 
  # typically by being looked up from disk again. Typically used for testing. 
  def reset!
    remove_instance_variable "@service_definitions"   if defined? @service_definitions
    remove_instance_variable "@services_config_list"  if defined? @services_config_list
  end

  def service_definition_for(service_id)
    return service_definitions[service_id]
  end

  # pass in array of service group ids. eg. ["group1", "-group2"]
  #
  # Returns a list of service definition hashes.
  #
  # Start with default group(s). Remove any that are mentioned with "-group_id" in
  # the group list, add in any that are mentioned with "group_id"
  def determine_services(specified_groups = [])    
    services = {}

    activated_service_groups = self.config.select do |group_id, group_definition|
      ((group_id == "default" || group_definition["default"] == true)  ||
      specified_groups.include?(group_id)) &&
      ! specified_groups.include?("-#{group_id}")
    end

    activated_service_groups.each_pair do |group_id, group_definition|
      services.merge! (group_definition["services"] || {})
    end

    # Remove any disabled services
    services.reject! {|service_id, hash| hash && hash["disabled"] == true}

    return services
  end


  # pass in string unique key OR a service definition hash,
  # and a current UmlautRequest.
  # get back instantiated Service object.
  def instantiate_service!(service, request)
    definition = service.kind_of?(Hash) ? service : service_definition_for(service.to_s)
    raise "Service '#{service}'' does not exist in umlaut-services.yml" if definition.nil?
    className = definition["type"] || definition["service_id"]
    classConst = Kernel.const_get(className)
    service = classConst.new(definition)
    service.request = request
    return service
  end
end
