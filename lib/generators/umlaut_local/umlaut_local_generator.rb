class UmlautLocalGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      # Create local directories, that can be included in local svn
      m.directory "public/local"
      m.directory "app/views/layouts/local"
      m.directory "app/views/local"
      m.directory "config/umlaut_config"
      m.directory "config/umlaut_config/initializers/umlaut"
      m.directory "config/umlaut_config/environments"
    
      # Create template files
      m.file "services.yml-dist", "config/umlaut_config/services.yml"
      m.file "institutions.yml-dist", "config/umlaut_config/institutions.yml"
      m.file "database.yml-dist", "config/umlaut_config/database.yml"
      m.file "umlaut_environment.rb", "config/umlaut_config/environment.rb"
      m.file "environments/development.rb", "config/umlaut_config/environments/development.rb"
      m.file "local_service_type_values.yml-dist", "config/umlaut_config/local_service_type_values.yml"

      # Create local initializers, start from our stock initializers, but
      # comment everything out.
      # Since we're copying from files in the main Rails app instead of
      # our local generator templates dir where the generator expects,
      #we need to use that crazy path with lots of "..". Oh well, it
      # works. 
      distro_rel_path = File.join( "../../../../config/initializers/umlaut".split("/"))

      Dir.foreach( File.join(RAILS_ROOT, "config", "initializers", "umlaut" )) do |file_name|
        # skip files begining with a period, such as ".svn", "." and ".."
        # skip files beginnning "#" too, vi temp files
        next if file_name[0..0] == '.'
        next if file_name[0..0] == '#'

        m.file( File.join(distro_rel_path, file_name), "config/umlaut_config/initializers/umlaut/#{file_name}") do |file|
            output = ""
            file.each_line do |line|
              # Comment out all lines in the file we're writing
              line = "# " + line unless line =~ /^\s*($|\#)/
              output << line
            end
            output
        end
      end
      m.readme "completion_message.txt"
    end
  end
end

