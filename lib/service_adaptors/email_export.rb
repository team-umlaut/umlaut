class EmailExport < AjaxExport

  def initialize(config)
    self.instance_variable_set("@controller", "export_email") if self.instance_variable_get("@controller").nil?
    self.instance_variable_set("@ajax_id", "email") if self.instance_variable_get("@ajax_id").nil?
    super(config)
  end

end
