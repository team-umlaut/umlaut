module SfxDb
  class SfxDbBase < ActiveRecord::Base
    # This guy uses a different db connection. We can establish that here, on
    # class-load. Please define an sfx_db database in databases.yml!
    # Some utility methods are also located in this class. 
    begin
      self.establish_connection :sfx_db
    rescue ActiveRecord::ActiveRecordError => e
      # Make it more descriptive for the newbies. 
      new_e = e.class.new(e.message + ": SfxDb classes require you to specify a database connection called sfx_db in your config/databases.yml.")
      new_e.set_backtrace( e.backtrace )
      raise new_e 
    end

    # All SfxDb things are read-only!
    def readonly?() 
      return true
    end

    # Atttempts to extract all URLs that SFX knows about from the db.
    # This process is not 100%, becuase of the way SFX calculates URLs
    # on the fly. We are only grabbing them from the db--and even the
    # way they are stored in the db is hard for us to grab reliably!
    # So this is really just a kind of guess heuristic in a bunch
    # of ways. 
    # But we do our best, and use this to load the SfxUrl model. 
    def self.fetch_sfx_urls
        # Fetch all target services that look like they might have a URL
        # in the parse param, and that are active. We know this misses ones
        # that are just active for certain institutes! Known defect.
        target_services = TargetService.find(:all, :conditions => "PARSE_PARAM like '%.%' and AVAILABILITY ='ACTIVE'")

        # Same with object portfolios, which can also have urls hidden in em
        object_portfolios = ObjectPortfolio.find(:all, :conditions => "PARSE_PARAM like '%.%' and AVAILABILITY = 'ACTIVE'")

        urls = []
        (target_services + object_portfolios).each do |db_row|
          parse_param = db_row.PARSE_PARAM

          # Try to get things that look sort of like URLs out. Brutal force,
          # sorry. 
          url_re = Regexp.new('(https?://\S+\.\S+)(\s|$)')
          urls.concat( parse_param.scan( url_re ).collect {|matches| matches[0]} )
          
        end
        urls.uniq!
        return urls        
    end

    
  end
end
