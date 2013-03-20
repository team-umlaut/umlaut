# Since this relies on finding holdings that exist, you need to run it in
# a service wave AFTER anything that might generate holdings. 
class TxtHoldingExport < AjaxExport

  def initialize(config)
    @display_text = "Send to phone"
    @form_controller = "export_email"
    @form_action = "txt"
    # providers is a hash of:
    # user-presentable-string => hostname for email to txt service. 
    @providers = {
     "Cingular/AT&T" => "cingularme.com",
     "Nextel" => "messaging.nextel.com",     
     "Sprint" => "messaging.sprintpcs.com",
     "T-Mobile"=> "tmomail.net",
     "Verizon"=> "vtext.com",
     "Virgin"=> "vmobl.com"
    }
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
