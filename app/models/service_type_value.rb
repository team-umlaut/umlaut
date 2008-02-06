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
end
