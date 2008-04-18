


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
      require 'yaml'
    
      # Load in starting set of ServiceTypeValue.
      puts "Loading service type values from db/orig_fixed_data/service_type_values.yml"
      ServiceTypeValue.enumeration_model_updates_permitted = true
      
      fixed_data_dir = File.join(RAILS_ROOT, "db", "orig_fixed_data")
      service_type_values = YAML.load_file( File::join(fixed_data_dir, 'service_type_values.yml') )
      
      service_type_values.each_pair do |name, hash|
        existing = ServiceTypeValue.find(:first, :conditions=>["id = ?", hash['id'] ])
        if (existing)
          puts "ServiceTypeValue #{name} NOT inserted, as id #{hash['id']} already exists in db."
        else
          # Add the YAML label to the hash, for initialization of our AR without
          # needing to repeat ourselves. 
          hash[:name] = name
          new_value = ServiceTypeValue.new( hash )
          new_value.id = hash['id']
          new_value.save!
        end      
      end
      ServiceTypeValue.enumeration_model_updates_permitted = false    
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
        puts "Expiring sessions older than #{expire_seconds} seconds."
        Request.connection.execute("delete from sessions where now() - updated_at > #{expire_seconds}")
      end


      desc "Cleanup of database for old data associated with expired sessions etc."
      task :expire_old_data => :environment do
        # There are requests, responses, and dispatched_service entries
        # hanging around for things that may be way old and no longer
        # need to hang around. How do we know if they're too old?
        # If they are no longer associated with any session, mainly.

        # Except, we can not delete old Requests and their associated
        # referent and referrer data, because they are used by the permalink
        # service (and possibly by statistics too). 
        
        # However, if a Request no longer has a live session, let's get rid
        # of all its ServiceTypes.

        # We do this with 'destroy', which is slow, because it fetches
        # everything into the db first. But I think that's okay. This
        # code assumes session store in ActiveRecord in a sessions table.
        
        puts "Deleting ServiceTypes for dead Requests..."
        orphaned_service_types = ServiceType.find(:all, :include => [:request], :conditions => "requests.session_id is null OR requests.session_id NOT IN (select session_id from sessions)")
  
        orphaned_service_types.each { |st| st.destroy }
        puts "  Deleted #{orphaned_service_types.length} ServiceTypes."
        
        # Now, let's get rid of any ServiceResponses that no longer have
        # ServiceTypes. 
        # Theoretically, a ServiceResponse can belong to more than one Request,
        # via different ServiceType joins. However, Umlaut doesn't currently
        # do that. 
        # Again with 'destroy' so all business rules for anything hanging off
        # ServiceResponse are triggered.
        
        puts "Deleting orphaned ServiceResponses..."
        orphaned_responses = ServiceResponse.find(:all, 
                    :include => [:service_types],
                    :conditions => "service_types.id is null")
        orphaned_responses.each { |r| r.destroy }
        puts "  Deleted #{orphaned_responses.length} ServiceResponses."

        # And get rid of DispatchedServices for 'dead' requests too. Don't
        # need em.

        puts "Deleting DispatchedServices for dead requests..."
        orphaned_dispatch =  DispatchedService.find(:all, :include => [:request], :conditions => "requests.session_id is null OR requests.session_id NOT IN (select session_id from sessions)")
        orphaned_dispatch.each {|d| d.destroy }
        puts "  Deleted #{orphaned_dispatch.length} DispatchedServices."


        # Turns out we need to get rid of old referents and referentvalues
        # too. There are just too many. This will make old permalinks no
        # longer work until we fix that. Let's delete referents and
        # referent values older than 90 days for now.
        # Tricky because we didn't have created_at in referent or 
        # referent_value.
        Referent.transaction do 
          referent_expire = 20.days.ago
          puts "Deleting Referents older than 20 days."

          #Referent.delete_all(["created_at < ? OR created_at is NULL", referent_expire])
          # No created_at in old Referents. Doh! Need to use subquery in
          # delete. Sorry if that's not db-independent. This sucks beavis. 
          
          Referent.connection.execute("DELETE referents FROM referents, requests WHERE referents.id = requests.referent_id AND requests.created_at < '#{referent_expire.to_formatted_s(:db)}'")
          
       

          
          # Now delete orphaned ReferentValue. Inner join on a delete
          # might not work in all databases, but it works on MySQL. Sorry can't
          # figure out a good db-independent Rails way to take care of this
          # purging.
          puts "Deleting orphaned ReferentValues."
          ReferentValue.connection.execute("DELETE FROM referent_values WHERE referent_values.referent_id is NULL OR NOT EXISTS (SELECT * FROM referents WHERE referents.id =  referent_values.referent_id)")          
        end        
      end
    
end
