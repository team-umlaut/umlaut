require 'umlaut'
require 'umlaut_configurable'

# Superclass for all Umlaut controllers, to hold default behavior,
# also hold global configuration. It's a superclass rather than a module,
# so we can use Rails 3 hieararchical superclass view lookup too if we want,
# for general umlaut views. And also so local app can over-ride
# methods here once, and have it apply to all Umlaut controllers.
# But there's not much magic in here or anything, the
# common behavior is ordinary methods available to be called, mostly. 
#
# This class is copied into the local app -- the default implementation
# does nothing but 'include Umlaut::ControllerBehavior'
#
# You will ordinarily set config here, and can also over-ride
# methods from Umlaut::ControllerBehavior if desired. Or add
# additional helpers to over-ride Umlaut helpers if needed. 
class UmlautController < ApplicationController
    include Umlaut::ControllerBehavior
        
end
