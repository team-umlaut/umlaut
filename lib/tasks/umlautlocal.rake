namespace :umlaut_lcl do
  # Key is path from RAILS_ROOT, value is location off of UMLAUT_LOCAL_SVN
  #, if user is using local svn. 
  Local_Dirs = {'public/local' => 'public_local',
                'app/views/layouts/local' => 'layouts_local',
                'app/views/local' =>  'views_local',
                'config/umlaut_config' => 'umlaut_config'}
  # Key is path to find template, value is path to copy to. 
  Local_Files = { 'config/umlaut_distribution/services.yml-dist' =>
                  'config/umlaut_config/services.yml',       
                  'config/umlaut_distribution/institutions.yml-dist' =>
                  'config/umlaut_config/institutions.yml',
                  'config/umlaut_distribution/database.yml-dist' =>
                  'config/umlaut_distribution/database.yml',
                  'config/umlaut_distribution/umlaut_environment.rb' =>
                  'config/umlaut_config/environment.rb'}


  desc "Create directories for local umlaut config files"
  task :generate => :environment do
    Local_Dirs.each do |local_path, svn_path|      
      full_path = RAILS_ROOT + '/' + local_path
      unless File.exist?(full_path)
        puts "Creating local config directory at #{full_path}"
        FileUtils.mkdir( full_path )
      end    
    end

    Local_Files.each do |source, dest|
      source_path = RAILS_ROOT + '/' + source
      dest_path = RAILS_ROOT + '/' + dest

      unless File.exist?(dest_path)
        File.copy( source_path, dest_path)
      end
    end
  end

  desc "Add local config to local SVN for the first time."
  task :import_to_svn => :environment do
     svn_root = local_svn_root()
  
     unless ( system("svn list #{svn_root} 1>/dev/null 2>/dev/null"))
       puts "Creating svn dir #{svn_root}"
       system("svn mkdir #{svn_root} -m 'added by umlaut rake task for local umlaut config.'")
     end     
     
     Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path
        full_svn_path = svn_root + '/' + svn_path

        unless ( system("svn list #{full_svn_path} 1>/dev/null 2>/dev/null"))
          puts "Adding #{full_local_path} to local svn."          
          system("svn mkdir #{full_svn_path} -m 'added by umlaut rake task for local umlaut config'")
        end

        system("svn checkout #{full_svn_path} #{full_local_path}")
        
        # Add each file/dir contents if neccesary. 
        Dir.foreach(full_local_path) do |filename|
          next if filename =~ /^\./ # skip dot files
          system("svn add #{full_local_path + '/' + filename}")
        end
        
     end
  end

  desc "Check out local config from your local svn to umlaut installation."
  task :checkout => :environment do
    svn_root = local_svn_root()
    Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path
        full_svn_path = svn_root + '/' + svn_path

        puts "svn checkout #{full_svn_path} #{full_local_path}"
        system("svn checkout #{full_svn_path} #{full_local_path}")
    end
  end

  desc "Svn update all local config"
  task :update => :environment do
     Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path

        puts "svn update #{full_local_path}"
        system("svn update #{full_local_path}")
    end
  end

  desc "Svn commit all local config"
  task :commit => :environment do
     Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path

        puts "svn commit #{full_local_path}"
        system("svn commit #{full_local_path} -m 'committed by umlaut rake task' ")
    end
  end
  
  desc "Svn status on all local config"
  task :status => :environment do
       Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path

        puts "svn status #{full_local_path}"
        system("svn status #{full_local_path}")
    end
  end

  def local_svn_root
    local_svn_root = UMLAUT_SVN_LOCAL if defined?(UMLAUT_SVN_LOCAL)
    local_svn_root = ENV['UMLAUT_SVN_LOCAL'] unless local_svn_root
    unless local_svn_root
      puts "Enter local svn root path: "
      local_svn_root = $stdin.gets.chomp
    end
    
  end
end
