module SfxDb
  # Was an sfx_db connection set in database.yml to connect
  # directly to sfx?
  def self.connection_configured?
    config = ActiveRecord::Base.configurations["sfx_db"]
    return (! config.blank? &&
            ! config['adapter'].blank?)    
  end
end

