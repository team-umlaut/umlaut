class EmailExport < AjaxExport

  def initialize(config)
    @display_text ||= "Email"
    @form_controller ||= "export_email"
    @form_action ||= "email"
    super(config)
  end

end
