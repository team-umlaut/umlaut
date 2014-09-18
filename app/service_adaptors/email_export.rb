class EmailExport < AjaxExport

  def initialize(config)
    @display_text ||= "Email"
    @display_text_i18n ||= "display_text"
    @form_controller ||= "export_email"
    @form_action ||= "email"
    super(config)
  end

end
