namespace :doc do

  desc "Upload current documentation to Rubyforge"
  task :upload_to_rforge => :environment do
    sh "scp -r doc/app/* "  "#{AppConfig.param('rubyforge_username', ENV['RUBYFORGE_USERNAME'])}@rubyforge.org:/var/www/gforge-projects/umlaut/api/"
  end
  
end
