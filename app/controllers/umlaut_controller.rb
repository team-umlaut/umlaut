require 'umlaut'


# Superclass for all Umlaut controllers, to hold default behavior,
# also hold global configuration. It's a superclass rather than a module,
# so we can use Rails 3 hieararchical superclass view lookup too if we want,
# for general umlaut views. But there's not much magic in here or anything, the
# common behavior is ordinary methods available to be called, mostly. . 
class UmlautController < ApplicationController
    include UmlautConfigurable
    include Umlaut::ErrorHandling
    include Umlaut::ControllerLogic
    
    helper Umlaut::Helper
    Umlaut.set_default_configuration!( umlaut_config )

end
