class Service
  attr_reader :priority
  def initialize(config)
    config.each do | key, val |
      self.instance_variable_set(('@'+key).to_sym, val)
    end
  end
end
