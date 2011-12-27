module Umlaut
  class Engine < Rails::Engine
    engine_name "umlaut"
    
    # This makes our rake tasks visible.
    rake_tasks do
      Dir.chdir(File.expand_path(File.join(File.dirname(__FILE__), '..'))) do
        Dir.glob(File.join('lib', 'tasks', '*.rake')).each do |railtie|
          load railtie
        end
      end
    end
  end
end
