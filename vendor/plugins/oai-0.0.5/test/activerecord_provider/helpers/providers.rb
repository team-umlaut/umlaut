require 'active_record'
require 'oai'
require "config/connection.rb"

Dir.glob(File.dirname(__FILE__) + "/../models/*.rb").each do |lib|
  require lib
end

class ARProvider < OAI::Provider::Base
  repository_name 'ActiveRecord Based Provider'
  repository_url 'http://localhost'
  record_prefix 'oai:test'
  source_model ActiveRecordWrapper.new(DCField)
end

class SimpleResumptionProvider < OAI::Provider::Base
  repository_name 'ActiveRecord Resumption Provider'
  repository_url 'http://localhost'
  record_prefix 'oai:test'
  source_model ActiveRecordWrapper.new(DCField, :limit => 25)
end

class CachingResumptionProvider < OAI::Provider::Base
  repository_name 'ActiveRecord Caching Resumption Provider'
  repository_url 'http://localhost'
  record_prefix 'oai:test'
  source_model ActiveRecordCachingWrapper.new(DCField, :limit => 25)
end
  

class ARLoader
  def self.load
    fixtures = YAML.load_file(
      File.join(File.dirname(__FILE__), '..', 'fixtures', 'dc.yml')
    )
    fixtures.keys.sort.each do |key|
      DCField.create(fixtures[key])
    end
  end
  
  def self.unload
    DCField.delete_all
  end
end
