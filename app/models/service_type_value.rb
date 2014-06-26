require 'yaml'


# This model is the actual list of valid service types. Not ActiveRecord,
# just load from config files into memory (loaded on file load). 
#
# ServiceTypeValues have human-displayable names, that are controlled by Rails I18n. 
#
# For a ServiceTypeValue with name 'fulltext', key in i18n at 'umlaut.service_type_names.fulltext.one'
# represents the singular (non-plural) name of objects of this ServiceTypeValue. 
#
# By default, the Rails pluralization inflector will be used to come up with the plural name. 
# But you can override with an I18n key (eg) "umlaut.service_type_names.fulltext.other"
#
# Note that these i18n translation keys follow the pattern of the built-in Rails I18n
# pluralization, but we don't actually use built-in pluralization algorithm, because
# we allow for a default using the Rails .pluralize inflector. We may move to built-in
# I18n pluralization in the future, especially if we need to support languages with more
# complex pluralization rules, that we aren't doing now. 
class ServiceTypeValue   
  attr_accessor :name, :id
  attr_writer :display_name, :display_name_plural
  
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

  def display_name
    I18n.t("one", :scope => "umlaut.service_type_names.#{self.name}", :default => :"umlaut.service_type_names.default.one")
  end
  
  def display_name_pluralize
    plural_hash = I18n.t(self.name, :scope => "umlaut.service_type_names", :default => "")
    if plural_hash.kind_of? Hash
      return plural_hash[:other] if plural_hash[:other]
      return plural_hash[:one].pluralize(I18n.locale)
    else
      return I18n.t("umlaut.service_type_names.default.other")
    end
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
