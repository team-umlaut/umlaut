class TxtHoldingExport < EmailExport

  def initialize(config)
    @controller ||= "export_email")
    @ajax_id ||= "txt"
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
