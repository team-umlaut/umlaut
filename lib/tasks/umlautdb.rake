


namespace :umlaut do
    desc "Perform nightly maintenance. Set up in cron."
    task :nightly_maintenance => [:load_sfx_urls, :expire_sessions, :expire_old_data]

    desc "Loads in initial set of irrelvant_sites and relevant_sites"
    task :load_sites => :environment do
      require 'active_record/fixtures'
      
      # Load a starting set of relevant_sites and irrelevant_sites
      # Magic from Rails book to load a fixture in a migration
      fixed_data_dir = File.join(RAILS_ROOT, "db", "orig_fixed_data")
    
    
      if ( RelevantSite.find(:first).nil? )
        puts "Loading a suggested starting list of relevant_sites."
        Fixtures.create_fixtures(fixed_data_dir, "relevant_sites")
      else
        puts "relevant_sites is not empty, so not loading initial data set."
      end
        
      if ( IrrelevantSite.find(:first).nil? )
        puts "Loading a suggested starting list of irrelevant_sites."
        Fixtures.create_fixtures(fixed_data_dir, "irrelevant_sites")
      else
        puts "irrelevant_sites is not empty, so not loading initial data set."
      end
    end
  
    desc "Loads in standard Rails service_type_values."
    task :load_service_type_values => :environment do            
       ServiceTypeValue.sync_values!
    end
    
    desc "Loads in all initial fixed data for an umlaut installation."
    task :load_initial_data => [:load_sites, :load_service_type_values] 
  
    desc "Syncs db to match config/umlaut_config/institutions.yml. Will create institutions as neccesary, but will never delete any institutions from db. "
    
    task :sync_institutions => :environment do
        # The method writes stuff to log, we don't want to write it to app
        # log, send it to stdout instead. 
        RAILS_DEFAULT_LOGGER = Logger.new(STDOUT)        
        Institution.sync_institutions!
    end

      desc "Loads sfx_urls from SFX installation. SFX mysql login needs to be set in config."
      task :load_sfx_urls => :environment do

        if SfxDb.connection_configured?
      
          puts "Loading SFXUrls via direct access to SFX db."
          urls = SfxDb::SfxDbBase.fetch_sfx_urls
          # We only want the hostnames
          hosts = urls.collect do |u|
            begin
            uri = URI.parse(u)
            uri.host
            rescue Exception
            end
          end
      
          SfxUrl.transaction do
            SfxUrl.delete_all
      
            hosts.each {|h| SfxUrl.new({:url => h}).create }      
          end
        else
          puts "Skipping load of SFXURLs via direct access to SFX db. No direct access is configured. Configure in config/umlaut_config/database.yml"
        end
      end

      desc "Expire sessions older than config.app_config.session_expire_seconds"
      task :expire_sessions => :environment do
        # Assume sessions are in db. 
        # Don't know good way to get the connection associated with sessions,
        # since there is no model. Assume Request is in the same db.
        expire_seconds = AppConfig.param("session_expire_seconds", 1.day)
        puts "Expiring sessions older than #{expire_seconds} seconds (set with config session_expire_seconds)."
        Request.connection.execute("delete from sessions where now() - updated_at > #{expire_seconds}")
      end


      desc "Cleanup of database for old data associated with expired sessions etc."
      task :expire_old_data => :environment do
        # There are requests, responses, and dispatched_service entries
        # hanging around for things that may be way old and no longer
        # need to hang around. How do we know if they're too old?
        # If they are no longer associated with any session, mainly.

        # Deleting things as aggressively as we're doing here doesn't leave
        # us much for statistics, but we aren't currently gathering any
        # statistics anyway. If statistics are needed, more exploration
        # is needed of performance vs. leaving things around for statistics. 

        # For efficiency, we delete with direct DB calls, so don't count
        # on Rails business logic being triggered! Was just WAY too slow
        # otherwise. Also, sorry, doing all this in a db efficient way (one db
        # query) requires some tricky SQL, which be MySQL specific. 

        # Current Umlaut never re-uses a request different between sessions, so
        # if the session is dead, we can purge the Requests too. Permalink
        # architecture has been fixed to not rely on requests or referents,
        # permalinks (post new architecture) store their own context object.

        puts "Deleting Requests no longer associated with a session."
        begin_time = Time.now
        work_clause = " FROM requests LEFT OUTER JOIN sessions ON requests.session_id = sessions.session_id WHERE sessions.id is null "
        count = ServiceType.count_by_sql("SELECT count(*) " + work_clause)
        Request.connection.execute("DELETE requests " + work_clause)
        puts "  Deleted #{count} Requests in #{Time.now - begin_time}"


        
        puts "Deleting ServiceTypes for dead Requests..."
        begin_time = Time.now
        work_clause =  " FROM (service_types LEFT OUTER JOIN requests ON service_types.request_id=requests.id) WHERE requests.id IS NULL "
        count = ServiceType.count_by_sql("SELECT count(*) " + work_clause )
        ServiceType.connection.execute("DELETE service_types " + work_clause)
        puts "  Deleted #{count} ServiceTypes in #{Time.now - begin_time}"


        
        # Now, let's get rid of any ServiceResponses that no longer have
        # ServiceTypes. 
        # Theoretically, a ServiceResponse can belong to more than one Request,
        # via different ServiceType joins. However, Umlaut doesn't currently
        # do that. 
        puts "Deleting orphaned ServiceResponses...."
        begin_time = Time.now
        work_clause = " FROM service_responses WHERE NOT EXISTS (SELECT * FROM service_types WHERE service_types.service_response_id =  service_responses.id)"
        count = ServiceResponse.count_by_sql("SELECT count(*) " + work_clause)
        ServiceResponse.connection.execute("DELETE " + work_clause)  
        puts "  Deleted #{count} ServiceResponses in #{Time.now - begin_time}"

        
        # And get rid of DispatchedServices for 'dead' requests too. Don't
        # need em.
        puts "Deleting DispatchedServices for dead Requests..."
        begin_time = Time.now
        # Sorry, may be MySQL only. 
        work_clause = " FROM (dispatched_services LEFT OUTER JOIN requests ON dispatched_services.request_id = requests.id)  WHERE requests.id IS NULL  "
        count = DispatchedService.count_by_sql("SELECT count(*) " + work_clause)
        DispatchedService.connection.execute("DELETE dispatched_services " + work_clause)
        puts "  Deleted #{count} DispatchedServices in #{Time.now - begin_time}"
        

        # Turns out we need to get rid of old referents and referentvalues
        # too. There are just too many. Permalinks have been updated to
        # store their own info and not depend on Referent existing. 
        referent_expire = Time.now - AppConfig.param("referent_expire_seconds", 20.days)
        puts "Deleting Referents/ReferentValues older than 20 days or config.referent_expires_seconds."
        begin_time = Time.now
        # May be MySQL dependent. 
        Referent.connection.execute("DELETE referents, referent_values FROM referents, referent_values where referents.id = referent_values.referent_id AND referents.created_at < '#{referent_expire.to_formatted_s(:db)}'" )
        puts "  Deleted Referents in #{Time.now - begin_time}"
                  
                
      end
    
end
