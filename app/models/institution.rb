#Services are grouped together in Institutions. An Institution represents some 
#particular class of user. It could be a particular location or affiliation, but 
#it really could be any other class of user too.
#
#Institutions are defined in $umlaut/config/umlaut_config/institutions.yml 
#(sample in config/umlaut_distribution/institutions.yml-dist ).  An Institution 
#definition is basically a unique identifier and a list of services attached to 
#that institution.
#
#
#Insitution is NOT an ActiveRecord; it's based off ruby Struct for simplicity,
# and generally loaded from institutions.yml  by the InstitutionList store
# class. #services is an array of service id's, NOT of actual Service objects.
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
class Institution < Struct.new(:postal_code, :worldcat_registry_id, :default_institution, :oclc_symbol, :services, :display_name)

  # Better initializer than Struct gives us, take a hash instead
  # of an ordered array. :services=>[] is an array of service ids,
  # not actual Services!
  def initialize(h={})
    members.each {|m|
        self.send( (m.to_s + '=') , (h[m.to_sym] || h[m]))
    }  
  end

  # Instantiates a new copy of all services included in this institution,
  # returns an array. 
  def instantiate_services!
    services.collect {|s|  }
  end
  

   
end
