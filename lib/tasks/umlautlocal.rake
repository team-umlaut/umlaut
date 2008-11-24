namespace :umlaut_lcl do
  # Key is path from RAILS_ROOT, value is location off of UMLAUT_LOCAL_SVN
  #, if user is using local svn. See lib/generators/umlaut_local for script
  # to create local files/directories. 
  Local_Dirs = {'public/local' => 'public_local',
                'app/views/layouts/local' => 'layouts_local',
                'app/views/local' =>  'views_local',
                'config/umlaut_config' => 'umlaut_config'}


  desc "Add local config to local SVN for the first time."
  task :import_to_svn => :environment do
     svn_root = local_svn_root()
  
     if ( system("svn list #{svn_root} 1>/dev/null 2>/dev/null"))
       puts "exists in svn #{svn_root}"
     else
       puts "Creating svn dir #{svn_root}"
       system("svn mkdir #{svn_root} -m 'added by umlaut rake task for local umlaut config.'")
     end     
     
     Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path
        full_svn_path = svn_root + '/' + svn_path

        if ( system("svn list #{full_svn_path} 1>/dev/null 2>/dev/null"))
          puts "exists in svn #{full_svn_path}"
        else
          puts "Adding #{full_local_path} to local svn."          
          system("svn mkdir #{full_svn_path} -m 'added by umlaut rake task for local umlaut config'")
        end

        if ( system("svn info #{full_local_path} 1>/dev/null 2>/dev/null"))
          puts "already svn working copy #{full_local_path}"
        else
          system("svn checkout #{full_svn_path} #{full_local_path}")
        end
        
        # Add each file/dir contents if neccesary. 
        Dir.foreach(full_local_path) do |filename|
          next if filename =~ /^\./ # skip dot files
          if ( system("svn info #{full_local_path} 1>/dev/null 2>/dev/null"))
            puts "already under svn control #{full_local_path}"
          else
            system("svn add #{full_local_path + '/' + filename}")
          end
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
     message = ENV["m"]
     message = 'commited by umlaut_lcl:commit rake task' unless message
  
     Local_Dirs.each do |local_path, svn_path|
        full_local_path = RAILS_ROOT + '/' + local_path

        puts "svn commit #{full_local_path} -m '#{message}'"
        system("svn commit #{full_local_path} -m '#{message}' ")
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
      print "Enter local svn root path: "
      local_svn_root = $stdin.gets.chomp
      # remove trailing slash if given
      local_svn_root.chop! if local_svn_root[ local_svn_root.length-1 , 1]
    end
    
  end
end
