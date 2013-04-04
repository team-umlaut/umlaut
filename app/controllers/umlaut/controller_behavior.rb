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
  # Local app can in theory override in local UmlautController to have
  # different custom behavior for calculating the collection, but this
  # is not entirely tested yet.
  def create_collection
    specified_groups = (params["specified_groups"].try {|str| str.split(",")}) || []

    services = {}

    unless specified_groups.delete "-default"
      services.merge ServiceStore.config["default"]["services"]
    end
    
    specified_groups.each do |group|
      services.merge ServiceStore.config[params["umlaut.service_group"]]
    end

    # Remove any disabled ones
    services = services.reject {|hash| hash && hash["disabled"] == true}

    return Collection.new(@user_request, services)
  end
  protected :create_collection
end