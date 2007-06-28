namespace :umlautdb do
    desc "Loads in initial fixed data for an umlaut installation."

    task :load_initial_data => :environment do\
       require 'active_record/fixtures'

    
       # Load a starting set of relevant_sites and irrelevant_sites
       # Magic from Rails book to load a fixture in a migration
       fixed_data_dir = File.join(RAILS_ROOT, "db", "orig_fixed_data")
       puts "Loading a suggested starting list of relevant_sites."
       Fixtures.create_fixtures(fixed_data_dir, "relevant_sites")
       puts "Loading a suggested starting list of irrelevant_sites."
       Fixtures.create_fixtures(fixed_data_dir, "irrelevant_sites")
    end

    desc "Syncs db to match config/institutions.yml. Will create institutions as neccesary, but will never delete any institutions from db. "
    
    task :sync_institutions => :environment do
        institutions = YAML.load_file(RAILS_ROOT+"/config/institutions.yml")

        institutions.each_pair do |name, yaml_record|
          inst = Institution.find(:first, :conditions => "name = '#{name}'")
          inst ||= Institution.new do |i| 
            i.name = name
            puts "Creating new institution for #{name}."
          end
          
          inst.default_institution = yaml_record["default_institution"] if yaml_record["default_institution"]

          inst.worldcat_registry_id = yaml_record["worldcat_registry_id"] if yaml_record["worldcat_registry_id"]
        
          inst.save
          puts "Institution #{name} synced."
        end
    end

    
end
