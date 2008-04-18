#Services are grouped together in Institutions. An Institution represents some 
#particular class of user. It could be a particular location or affiliation, but 
#it really could be any other class of user too.
#
#Institutions are defined in $umlaut/config/umlaut_config/institutions.yml 
#(sample in config/umlaut_distribution/institutions.yml-dist ).  An Institution 
#definition is basically a unique identifier and a list of services attached to 
#that institution.
#
#While Institutions are defined in the institution.yml config file, certain 
#attributes of the Institution are ALSO stored in the database for quicker 
#lookup (This may or may not make sense, but is a legacy design). After editing 
#the institution.yml file, a rake task should be run to sync the info to the db 
#too:
#:rake umlaut:sync_institutions
#
#The Insitution ActiveRecord automatically loads in properties stored in the 
#institutions.yml, helped out by the InstitutionList store class.
#
#Hypothetically, there will be many ways for a given incoming request to get 
#associated with an Institution: by IP range, by user preference, by attribute 
#from an enterprise directory associated with a  user account, etc. An incoming 
#user can be associated with one or more institutions.
#
#However, at present, pretty much the only way for a user to be associated with 
#an Institution is if it's a default Institution! So the only Institutions are 
#default Institutions at present (there can be more than one default 
#institution). This architecture has room for expansion.

class Institution < ActiveRecord::Base
  has_and_belongs_to_many :users
    
  def display_name
    self.load_configuration unless @display_name
    return @display_name
  end

  def display_name
    self.load_configuration unless @postal_code
    return @postal_code
  end
  
  def oclc_symbol
    self.load_configuration unless @oclc_symbol
    return @oclc_symbol
  end

  def services
    self.load_configuration unless @services
    return @services
  end    
  protected

  # Some Institution properties are kept in umlaut_config/institutions.yml
  # instead of in the db. This method will make sure to grab those and
  # store them in the Institution object. 
  def load_configuration
    unless i = InstitutionList.get(self.name)
      i = YAML.load(self.configuration)
    end
    @display_name = i["display_name"]
    @postal_code = i["postal_code"]
    @oclc_symbol = i["oclc_symbol"]
    self.load_services(i["services"]) if i["services"]
  end
  def load_services(svc_list)
    @services = []
    svc_list.each do | svc |
      @services << ServiceList.get(svc)
    end
  end

  @@inst_yml_ctime = nil
  @@inst_yml_ctime_checked = nil
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
    if ( @@inst_yml_ctime.nil? || @@inst_yml_ctime_checked < Time.now - 60 )
      path = File.join( RAILS_ROOT, "config", "umlaut_config", "institutions.yml")
      @@inst_yml_ctime = File.new(path).ctime
      @@inst_yml_ctime_checked = Time.now
    end    
    
    return time.nil? || @@inst_yml_ctime > time
  end

  # Syncs Institution in db with umlaut_config/institutions.yml, only if
  # the db is out of date with file modified timestamp. 
  def self.sync_institutions
    db_time = Institution.minimum(:updated_at)
    file_path = File.join( RAILS_ROOT, "config", "umlaut_config", "institutions.yml")
    file_time = File.new(file_path).ctime

    if ( file_time.nil? || file_time > db_time)
      sync_institutions!
    end
  end
  
  #Syncs db to match config/umlaut_config/institutions.yml. Will create
  # institutions as neccesary, but will never delete any institutions from db.
  # Will run whether or not it's neccesary. Run sync_institutions to check
  # timestamp first.   
  def self.sync_institutions!    
      institutions = YAML.load_file(RAILS_ROOT+"/config/umlaut_config/institutions.yml")
  
      institutions.each_pair do |name, yaml_record|
        inst = Institution.find(:first, :conditions => "name = '#{name}'")
        inst ||= Institution.new do |i| 
          i.name = name
          RAILS_DEFAULT_LOGGER.info("Creating new institution for #{name}.")
        end
        
        inst.default_institution = yaml_record["default_institution"] if yaml_record["default_institution"]
  
        inst.worldcat_registry_id = yaml_record["worldcat_registry_id"] if yaml_record["worldcat_registry_id"]
      
        inst.save!
        RAILS_DEFAULT_LOGGER.info("Institution #{name} synced.")
      end
  end
  
end
