class Service
  attr_reader :priority
  def initialize(config)
    @priority = config["priority"]
  end
end
