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

  # Returns the search layout name unless this is an XML HTTP Request.
  def search_layout_except_xhr
    @layout_name ||= (request.xhr? || params["X-Requested-With"] == "XmlHttpRequest") ?
      nil : umlaut_config.search_layout
  end
  protected :search_layout_except_xhr

  # We intentionally use a method calculated at request-time for layout,
  # so it can be changed in config at request-time.
  def resolve_layout
    umlaut_config.resolve_layout
  end
  protected :resolve_layout

  # Returns a Collection object with currently configured services.
  # Loads from Rails.root/config/umlaut_services.yml
  #
  # &umlaut.service_group may be used to customize which services are loaded,
  # else default.  &umlaut.service_group=-default turns off default. Can also
  # list other groups, comma seperated. 
  #
  # Local app that wants to automatically set services based on IP or other
  # implicit parameters, should add a before_filter that determines proper
  # service_group argument, and then sets it in params (or redirects). 
  # Not entirely tested yet. 
  def create_collection
    services = Collection.determine_services(params, ServiceStore)    

    return Collection.new(@user_request, services)
  end
  protected :create_collection



end