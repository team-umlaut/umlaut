#Services are grouped together in Institutions. An Institution typically
#represents someparticular class of user. It could be a particular location or
#affiliation, but it really could be any logical set of services. 
#
#Institutions are defined in $umlaut/config/umlaut_config/institutions.yml 
#(sample in config/umlaut_distribution/institutions.yml-dist ).  An Institution 
#definition is basically a unique identifier and a list of services attached to 
#that institution.
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
  include Singleton # get the instance with InstitutionList.instance
  @@institutions_yaml_path = RAILS.root +"/config/umlaut_config/institutions.yml"
  
  def initialize
    @institutions = nil
  end

  # Pretty much only used for testing. 
  def self.yaml_path=(path)
    @@institutions_yaml_path = path
    self.instance.reload
  end

  # Returns an Institution
  def get(name)
    return cached_institutions[name]
  end

  # Returns an array of Institution
  def default_institutions
     return cached_institutions.values.find_all {|i| i.default_institution == true}
  end

    
  def reload
    @institutions = nil
    cached_institutions
    true
  end
  
  def cached_institutions
    unless @institutions      
      ilist = YAML.load_file( @@institutions_yaml_path )
      @institutions = {}
      # Turn the institution hashes to Institutions please
      ilist.each_pair do |key, i_hash|        
        @institutions[key] = Institution.new(i_hash)
      end
    end
    
    return @institutions
  end
  
end
