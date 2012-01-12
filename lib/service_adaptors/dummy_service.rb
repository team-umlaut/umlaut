#
# A Dummy service that may be useful for testing (manual or perhaps in automated
# tests), that simply creates the responses you tell it to, after sleeping the
# amount you tell it to. 
#
#    DummyService:
#      type: DummyService
#      priority: 3
#      sleep: 4.5 # seconds
#      responses:
#        - service_type_value: fulltext
#          display_text: foo
#          url: http://google.com
#        - service_type_value: highlighted_link
#          display_text: bar
#          url: http://amazon.com
# 
class DummyService < Service
  attr_accessor :responses, :sleep
  
  def initialize(config = {})
    self.responses = []
    self.sleep = 0
    super
  end
  
  def service_types_generated
    responses.collect {|r| ServiceTypeValue[ r["service_type_value"] ]}.compact.uniq
  end
  
  def handle(request)
    
    ::Kernel.sleep( self.sleep ) if self.sleep
    
    responses.each do |response|   
      debugger
      request.add_service_response( { :service => self }.merge(response.symbolize_keys ) )
    end
    
    return true
  end
  
  
  
end
