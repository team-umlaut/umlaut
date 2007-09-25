namespace :umlaut_lcl do
  # Key is path from RAILS_ROOT, value is location off of UMLAUT_LOCAL_SVN
  #, if user is using local svn. 
  Local_Dirs = {'public/local' => 'public_local',
                'app/views/layouts/local' => 'layouts_local',
                'app/views/local' =>  'views_local',
                'config/umlaut_config' => 'umlaut_config'}

  UMLAUT_SVN_LOCAL ='https://svn.mse.jhu.edu/repos/public/trunk/scratch/rochkind/umlaut_local3'

  desc "Create directories for local umlaut config files"
  task :create_local_files => :environment do
    Local_Dirs.each do |local_path, svn_path|
      
      full_path = RAILS_ROOT + '/' + local_path
      unless File.exist?(full_path)
        puts "Creating local config directory at #{full_path}"
        FileUtils.mkdir( full_path )
      end    
    end      
  end

  desc "Add local config to local SVN for the first time."
  task :import_to_svn => :environment do
     unless ( system("svn list #{UMLAUT_SVN_LOCAL} 1>/dev/null 2>/dev/null"))
       puts "Creating svn dir #{UMLAUT_SVN_LOCAL}"
       system("svn mkdir #{UMLAUT_SVN_LOCAL} -m 'added by umlaut rake task for local umlaut config.'")
     end     
     
     Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path
        full_svn_path = UMLAUT_SVN_LOCAL + '/' + svn_path

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
     puts "Local files added to your local svn. We leave the committing to you."
  end

  desc "Check out local config from your local svn to umlaut installation."
  task :checkout => :environment do
    Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path
        full_svn_path = UMLAUT_SVN_LOCAL + '/' + svn_path

        puts "svn checkout #{full_svn_path} #{full_local_path}"
        system("svn checkout #{full_svn_path} #{full_local_path}")
    end
  end

  desc "Update all local config stuff"
  task :update => :environment do
     Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path
        full_svn_path = UMLAUT_SVN_LOCAL + '/' + svn_path

        puts "svn update #{full_svn_path} #{full_local_path}"
        system("svn update #{full_svn_path} #{full_local_path}")
    end
  end

  desc "Commit all local config stuff"
  task :commit => :environment do
     Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path
        full_svn_path = UMLAUT_SVN_LOCAL + '/' + svn_path

        puts "svn commit #{full_svn_path} #{full_local_path}"
        system("svn commit #{full_svn_path} #{full_local_path}")
    end
  end

  
end
