

class GenericOAIClient
  include OAIClient
  
  def do_request    
    return self.do_simple_request
  end  

end