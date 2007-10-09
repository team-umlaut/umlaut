module Test::Unit
  class AutoRunner
    alias_method :real_run, :run
    
    def run
      ProviderServer.wrap { real_run }
    end

  end
  
end
