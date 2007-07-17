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
# You can add your own localized ServiceTypeValues into the db too (please start
# at id 1000), or change the display_name of standard umlaut ones. Do not
# change the name attribute of standard umlaut ones, or umlaut code will break!
class ServiceTypeValue < ActiveRecord::Base
  acts_as_enumerated :on_lookup_failure => :enforce_strict
  
end
