
def umlaut_configuration(config)

  ar_logger = config.logger.clone
  ar_logger.level = Logger::INFO
  ActiveRecord::Base.logger = ar_logger
  config.logger.info("ActiveRecord logging set to level 'info' by Umlaut for clearer logs. To change this, see config/umlaut_config/development.rb")

end
