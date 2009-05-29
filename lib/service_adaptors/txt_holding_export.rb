class TxtHoldingExport < EmailExport

  def initialize(config)
    self.instance_variable_set("@controller", "export_email") if self.instance_variable_get("@controller").nil?
    self.instance_variable_set("@ajax_id", "txt") if self.instance_variable_get("@ajax_id").nil?
    super(config)
  end

  def handle(request)
    holdings = request.get_service_type('holding', { :refresh => true })
    unless holdings.nil? or holdings.empty?
      super(request)
    else
      return request.dispatched(self, true)
    end
  end
  
end
