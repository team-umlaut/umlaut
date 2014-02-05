class EmailExport < AjaxExport

  def initialize(config)
    @display_text ||= :email
    @form_controller ||= "export_email"
    @form_action ||= "email"
    super(config)
  end

end
