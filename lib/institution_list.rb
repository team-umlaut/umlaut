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

class InstitutionList
  private_class_method :new
  @@institutions = nil
  
  def self.get(name)
    @@institutions = YAML.load_file(RAILS_ROOT+"/config/umlaut_config/institutions.yml") unless @@institutions
    return @@institutions[name]
  end  
end