class ServiceBundle
  attr_accessor :services
  def initialize(service_objects)
    @services = service_objects
  end
  def handle(request) 
    threads = []
    @services.each { | service |
      threads << Thread.new(request, service) { | Thread.current[:request], Thread.current[:service] |
        curr = Thread.current
        curr[:service].handle(curr[:request])
      }
    }    
    threads.each { |aThread|  
      begin 
        aThread.join            
      rescue NoMethodError        
      end
    }
  end  
end