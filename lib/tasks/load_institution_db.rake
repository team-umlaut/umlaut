namespace :institutions do
    desc "Syncs db to match config/institutions.yml. Will create institutions as neccesary, but will never delete any institutions from db. "
    
    task :sync_to_db => :environment do
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
