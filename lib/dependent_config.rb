# Sometimes you need to define a config property in terms of some other config
# property. You might want the first config property to be capable of being 
# over-ridden locally, and you want that new over-ridden value to be used to 
# compute the second property.

# But order of execution can make this tricky to make work right. Solution,
# use a DependentConfig. This allows you to supply some logic for calculating a
# config value (technically a 'closure', in the form of a rails block), which 
# Umlaut can re-trigger after all local config has been set (by calling the
# class method #permanently_reset_all), to re-calculate based on over-ridden
# dependencies.
#
# The calculation passed in as a closure should be fairly cheap to make, and
# it should be fine to re-run it an arbitrary number of times. The closure 
# (ie block) shouldn't have any side effects that aren't idempotent, and should
# ideally always return an object of the same class. 
# 
#
# Example:
#
#   AppConfig::Base.opensearch_description = DependentConfig.new {"Search #{AppConfig::Base.app_name} for journal names containing your term."}
#
#
class DependentConfig < Delegator
  @@_list = []  

  def initialize( &my_closure)
      @_my_closure = my_closure
      super(__getobj__)
      # keep track in a class variable of all DependentConfigs, so we
      # can easily #permanently_reset them all later.
      @@_list << self
  end

  def __getobj__
    @_result ||= @_my_closure.call
  end
  
  def __setobj__(v)
    @_result = v
  end
    
  def __reset_closure__
    raise Exception.new("Can't reset, has been permanently reset or is missing closure for other reason") unless @_my_closure
    @_result = nil
  end

  def __permanently_reset__
    __reset_closure__
    # recalc one more time before we toss out the closure
    __getobj__
    @_my_closure = nil
  end

  
  ## But we go beyond what Delegator does, and over-ride is_a?, kind_of?
  # and instance_of?, to make our impersonation truly complete. Holy
  # multiple inheritance, batman!  Not really sure why Delegator's
  # logic doesn't apply to these methods already. 
  def instance_of?(obj)
    super(obj) || (__getobj__).instance_of?(obj)    
  end
  def kind_of?(obj)
    super(obj) || (__getobj__).kind_of?(obj)
  end
  def is_a?(obj)
    super(obj) || (__getobj__).kind_of?(obj)
  end

  def self.permanently_reset_all
    @@_list.each do |config_closure|
      config_closure.__permanently_reset__
    end
    # And no need to track them anymore. 
    @@_list = []
  end

end

