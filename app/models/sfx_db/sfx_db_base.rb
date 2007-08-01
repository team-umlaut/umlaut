module SfxDb
  class SfxDbBase < ActiveRecord::Base
    # This guy uses a different db connection. We can establish that here, on
    # class-load. Please define an sfx_db database in databases.yml!
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
  end
end
