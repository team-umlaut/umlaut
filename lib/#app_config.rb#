# This should NOT remain past the rails 3.x migration -- it's a stand-in
# letting our existing code that used the AppConfig plugin kind of keep
# working, even though the plugin we were using is not compatible with
# new versions of rails. Eventually we'll do config completely different. 

module AppConfig
  Base = AppConfig
  
  def self.method_missing(msg, *args)    
    if msg.to_s =~ /^(.*)\=$/      
      set($1, *args)
    else      
      param(msg)
    end
  end
  
  def self.singleton
    @@singleton ||= AppConfig::Imp.new
  end
  
  def self.param(*args)
    singleton.param(*args)
  end
  
  def self.[](*args)
    singleton.param(*args)
  end
  
  def self.set(*args)
    singleton.set(*args)
  end
  
  class Imp
  
    def param(value, default_value = nil)
      config[value.to_s] || default_value
    end
    
    def set(key, value)
      config[key.to_s] = value
    end
    
    def config
      @config ||= Hash.new
    end
  end
  
end
