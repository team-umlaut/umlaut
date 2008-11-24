# This model is the actual list of valid service types. Since it uses the
# acts_as_enumerated plugin, you can in code just do something like
# ServiceTypeValue[:fulltext], to get the relevant ServiceTypeValue
# in an efficient and easy way.
#
# ServiceTypeValue's also have displable strings, stored in the
# display_name attribute.
#
# Load the standard Umlaut set of ServiceTypeValues into your db by running
# rake umlautdb:load_initial_data
# This will load in data stored in db/orig_fixed_data/service_type_values.yml.
#
# We should create a mechanism for locally-defined types that doesn't
# require modifying this SVN-controlled file. 
# Locally defined ServiceTypeValues should start at
# at id 1000. The display_name of standard umlaut ServiceTypeValues might also
# be changed.ones. Do not change the name attribute of standard umlaut
# ServiceTypeValues, or umlaut code will break!
class ServiceTypeValue < ActiveRecord::Base
  acts_as_enumerated :on_lookup_failure => :enforce_strict
  
  def display_name_pluralize
    return self.display_name_plural || self.display_name.pluralize
  end

  @@distro_conf_file = File.join(RAILS_ROOT, "db", "orig_fixed_data", "service_type_values.yml")
  @@local_conf_file = File.join(RAILS_ROOT, "config", "umlaut_config", "local_service_type_values.yml")
  
  # Syncs db with db/orig_fixed_data/service_type_values.yml, only if
  # the db is out of date with file modified timestamp. 
  def self.load_values
    db_time = ServiceTypeValue.minimum(:updated_at)

    distro_file_time = File.new(@@distro_conf_file).ctime
    local_file_time = File.exists?(@@local_conf_file) ?
      File.new(@@local_conf_file).ctime : 
      db_time
    
    
    if ( db_time.nil? || (distro_file_time > db_time) || (local_file_time > db_time))
      load_values!
    end
  end

  
  #Syncs db to match db/orig_fixed_data/service_type_values.yml, 
  # but will never delete anything from db.
  # Will run whether or not it's neccesary. Run load_values to check
  # timestamp first.   
  def self.load_values!
      require 'yaml'

      # Load in starting set of ServiceTypeValue, merge in local defines. 
      puts "Loading service type values from db/orig_fixed_data/service_type_values.yml and config/umlaut_config/local_service_type_values.yml"
      
      ServiceTypeValue.enumeration_model_updates_permitted = true
      
      service_type_values = YAML.load_file( @@distro_conf_file )
      local_overrides = File.exists?( @@local_conf_file ) ?
            YAML.load_file(@@local_conf_file) :
            nil
      # Merge in the params for each service type with possible
      # existing params.
      if ( local_overrides )
        local_overrides.each do |name, params|
          if ( service_type_values[name])
            service_type_values[name].merge!(params )
          else
            service_type_values[name] = params
          end
        end
      end
      
      service_type_values.each_pair do |name, hash|
        existing = ServiceTypeValue.find(:first, :conditions=>["id = ?", hash['id'] ])

        # Either over-write existing, or add new! 
        value_obj = existing || ServiceTypeValue.new
        # Add the YAML label to the hash, for initialization of our AR without
        # needing to repeat ourselves. 
        hash['name'] = name
        hash.each do |key, value|
          value_obj[key] = value
        end
        # force save by setting updated_at
        value_obj.updated_at = Time.now
        value_obj.save!
        
        #if (existing)
        #  puts "ServiceTypeValue #{name} NOT inserted, as id #{hash['id']} already exists in db."
        #else
          # Add the YAML label to the hash, for initialization of our AR without
          # needing to repeat ourselves. 
        #  hash[:name] = name
        #  new_value = ServiceTypeValue.new( hash )
        #  new_value.id = hash['id']
        #  new_value.save!
        #end      
      end
      ServiceTypeValue.enumeration_model_updates_permitted = false

      RAILS_DEFAULT_LOGGER.info("ServiceTypeValues loaded from config file.")
  end
end
