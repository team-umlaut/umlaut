module OAI::Provider::Response
  class Error < Base
    
    def initialize(provider, error)
      super(provider)
      @error = error
    end
    
    def to_xml
      response do |r|
        r.error @error.to_s, :code => @error.code
      end
    end
    
  end
end