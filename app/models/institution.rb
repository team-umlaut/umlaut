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
end
