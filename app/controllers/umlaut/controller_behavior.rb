# All behavior from UmlautController is extracted into this module,
# so that we can generate a local UmlautController that includes
# this module, and local app can configure or over-ride default behavior.
#
#
# This is really only intended to be included'd by UmlautController;
# other controllers may sub-class UmlautController
module Umlaut::ControllerBehavior
  extend ActiveSupport::Concern

  include UmlautConfigurable
  include Umlaut::ErrorHandling
  include Umlaut::ControllerLogic

  included do |controller|
    controller.helper Umlaut::Helper # global umlaut view helpers
    # init default configuration values
    UmlautConfigurable.set_default_configuration!(controller.umlaut_config)
    # Set locale from request param
    controller.before_filter :set_locale
  end


  # Set the current locale based on request param umlaut.locale
  # Local app can override this in UmlautController if you'd like to
  # base locale on HTTP headers or IP address or other things. 
  def set_locale
    I18n.locale = params['umlaut.locale'.to_sym] || I18n.default_locale
  end

  # Rails over-ride to ensure locale is always included in
  # generated URLs. We choose to explicitly include locale's
  # only for non-default locale. 
  # Local app may override this in UmlautController to make
  # other choices. 
  def default_url_options(*arguments)
    if I18n.locale == I18n.default_locale
      # Don't add in param for default locale
      super
    else
      super.merge({ 'umlaut.locale'.to_sym => I18n.locale })
    end
  end



  # Returns the search layout name unless this is an XML HTTP Request.
  def search_layout_except_xhr
    @layout_name ||= (request.xhr? || params["X-Requested-With"] == "XmlHttpRequest") ?
      false : umlaut_config.search_layout
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
  # list other groups: NOTE: Needs to be submitted as a rails array,
  # &umlaut.service_group[]= 
  #
  # Local app that wants to automatically set services based on IP or other
  # implicit parameters, should add a before_filter that determines proper
  # service_group argument, and then sets it in params (or redirects). 
  # Not entirely tested yet. 
  #
  # See https://github.com/team-umlaut/umlaut/wiki/Alternate-service-groups
  def create_collection
    services = ServiceStore.global_service_store.determine_services( self.specified_service_groups.uniq )
    return Collection.new(@user_request, services)
  end
  protected :create_collection

  
  def specified_service_groups(arg_params = params)    
    specified_groups = params["umlaut.service_group"] || []
    specified_groups = [specified_groups] if specified_groups.kind_of?(String)
    
    return specified_groups
  end
  protected :specified_service_groups



end
