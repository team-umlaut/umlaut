# All behavior from UmlautController is extracted into this module,
# so that we can generate a local UmlautController that includes
# this module, and local app can configure or over-ride default behavior. 
# 
module Umlaut::ControllerBehavior
  extend ActiveSupport::Concern
  
  include UmlautConfigurable
  include Umlaut::ErrorHandling
  include Umlaut::ControllerLogic
  
  included do |controller|
    controller.helper Umlaut::Helper # global umlaut view helpers
    
    # init default configuration values
    UmlautConfigurable.set_default_configuration!(controller.umlaut_config)
  end
  
  
end
