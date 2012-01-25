namespace :umlaut do
    
    desc "Migrate permalinks from an umlaut 2.x installation"
    task :migrate_permalinks, [:connection] => [:environment] do |t,args|
      old_connection_name = args[:connection] || "umlaut2_source"    
      from_id = ENV['FROM_ID']
      
      import_batch = (ENV['IMPORT_BATCH'] || 20000).to_i
      export_batch = (ENV['EXPORT_BATCH'] || 20000).to_i
      gc_batch = (ENV['GC_BATCH'] || 100000).to_i
      
      begin        
        require 'activerecord-import'        
        ar_import = true
      rescue LoadError
        ar_import = false
      end
      
      # Turn off all caching we can think of with AR, cause it's gonna
      # take too much memory! I _think_ this will do that. 
      ActiveRecord::IdentityMap.enabled = false
      
      
      unless ActiveRecord::Base.configurations[old_connection_name]
        raise Exception.new("You must have a connection for '#{old_connection_name}' configured in database.yml, pointing to the Umlaut 2.x source db.")
      end
            
      puts "\nWARNING: We will delete all existing permalinks " + (from_id ? "(id >= #{from_id})" : "") +  " from the '#{Rails.env}' database:"   
      puts "  " + {}.merge(Permalink.connection_config).inspect
      print "\nSure you want to continue? (yes to continue) "
      continue = $stdin.gets
      raise Exception.new("Cancelled by user") unless continue.chomp == "yes" 
      
      puts "\nDeleting...\n"
      rel = Permalink
      rel = rel.where("id >= #{from_id}") if from_id      
      rel.delete_all
      
      # dynamically create a model for Permalinks in old
      # db, set up with connection info to old db. 
      OldPermalink = Class.new(ActiveRecord::Base) do
        self.set_table_name("permalinks")
        # just to be safe
        def read_only?
          true
        end
      end
      # Can't include this line in dynamic class generation above,
      # have to do it now that we have a constant assigned, for it
      # to work. 
      OldPermalink.establish_connection old_connection_name.to_sym
      
      puts "\nThis may take a while #{"(include activerecord-import gem for faster importing)" unless ar_import}...\n"

      # Read all the old Permalinks in, write em out to new
      # db, _with same primary key_ since PK is used for actual
      # user-facing permalinks. We don't copy the Referent relationship,
      # we just copy enough to recreate, context_obj_serialized.
      could_not_migrate = {
        :count => 0,
        :highest_id => 0,
        :latest_date => 0
      }
      highest_id = 0
      bulk_queue = []
      i = 0
      
      
      ActiveRecord::Base.uncached do 
        rel = OldPermalink
        rel = rel.where("id >= #{from_id}") if from_id

        rel.find_each(:batch_size => import_batch) do |old_p|
          i += 1
          
          highest_id = [highest_id, old_p.id].max
          
          if old_p.context_obj_serialized.blank?
            could_not_migrate[:count] += 1
            count_not_migrate[:highest_id] = [count_not_migrate[:highest_id], old_p.id].max
            could_not_migrate[:latest_date] = [could_not_migrate[:latest_date], old_p.created_on].max
          else        
            new_p = Permalink.new
            new_p.id = old_p.id # keep the id the same!
            new_p.created_on = old_p.created_on # why not keep it the same?
            new_p.orig_rfr_id = old_p.orig_rfr_id # why not
            
            # the important thing to be able to actually resolve it
            new_p.context_obj_serialized = old_p.context_obj_serialized
            
            if ar_import
              bulk_queue << new_p
            else
              new_p.save!
            end
          end
  
          print(".") if i % 1000 == 0 
          
          if i % gc_batch == 0
            GC.start 
            print "*"
          end
          
          if ar_import && i % export_batch == 0
            print "-" 
            Permalink.import(bulk_queue, :validate => false, :timestamps => false)
            print "+"
            bulk_queue.clear            
          end
          
        end
      end
      
      unless bulk_queue.empty?
        print "+"
        Permalink.import(bulk_queue, :validate => false, :timestamps => false)
      end
                  
      if could_not_migrate[:count] > 0
        puts "\n\nCould not migrate #{could_not_migrate[:count]} permalinks"
        puts "   Ending at permalink #{could_not_migrate[:highest_id]}, "
        puts "   created at #{could_not_migrate[:latest_date]}"
      end
      
      puts "\nDone. Highest ID migrated: #{highest_id}"
      
    end
    
  end
