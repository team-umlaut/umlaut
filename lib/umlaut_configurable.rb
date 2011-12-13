# meant to be included in _controllers_, to get an
# umlaut_config method as a class_attribute (avail on class, overrideable
# on instance), exposed as helper method too, 
# that has a Confstruct configuration object that starts out
# holding global config. (right now via a direct refernce to the global
# one). 
module UmlautConfigurable
  extend ActiveSupport::Concern
  
  included do
    class_attribute :umlaut_config
    helper_method :umlaut_config
    self.umlaut_config = Confstruct::Configuration.new
  end
  
end
