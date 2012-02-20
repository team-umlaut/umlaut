require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rdoc/task'
require 'rake/packagetask'
require 'rubygems/package_task'



Rake::TestTask.new('test') do |t|
  t.libs << 'lib'
  t.pattern = 'test/*_test.rb'
  t.verbose = true
  t.ruby_opts = ['-r openurl', '-r test/unit']
end

Rake::RDocTask.new('doc') do |rd|
  rd.rdoc_files.include("lib/**/*.rb")
  rd.rdoc_files.include("README")
  rd.rdoc_files.include("Changes")
  rd.main = 'README'
  rd.options << "--all"
  rd.rdoc_dir = 'doc'
end
