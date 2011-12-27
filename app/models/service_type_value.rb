require 'yaml'


# This model is the actual list of valid service types. Not ActiveRecord,
# just load from config files into memory (loaded on file load). 
#
# ServiceTypeValue's also have displable strings, stored in the
# display_name attribute, and possibly custom display_name_plural
class ServiceTypeValue   
  attr_accessor :name, :id, :display_name, :display_name_plural
  
  class << self; attr_accessor :values; end  
  
  def initialize(hash)
    hash.each_pair do |key, value|
      self.send(key.to_s+"=", value)
    end
  end
  
  def self.find(name)
    load_values! if values.nil?
    values[name.to_sym] or raise ArgumentError.new("No ServiceTypeValue found for #{name}")
  end
  def self.[](name)
    find(name)
  end
  
  def display_name_pluralize
    return self.display_name_plural || self.display_name.pluralize
  end
  
  @@distro_conf_file = File.join(Umlaut::Engine.root, "db", "orig_fixed_data", "service_type_values.yml")
  @@local_conf_file = File.join(Rails.root, "config", "umlaut_service_type_values.yml")
  
  
  # Loads from config files, distro and local, into memory.   
  def self.load_values!
      # Load in starting set of ServiceTypeValue, merge in local defines. 
      
      service_type_values = YAML.load_file( @@distro_conf_file )
      local_overrides = File.exists?( @@local_conf_file ) ?
            YAML.load_file(@@local_conf_file) :
            nil
      # Merge in the params for each service type with possible
      # existing params.
      if ( local_overrides )
        local_overrides.each do |name, params|
          service_type_values[name] ||= {}          
          service_type_values[name].merge!( params )          
        end
      end
      
      self.values = {}
      service_type_values.each_pair do |name, hash|
        self.values[name.to_sym] = ServiceTypeValue.new(hash.merge(:name => name))                              
      end            
  end
end
