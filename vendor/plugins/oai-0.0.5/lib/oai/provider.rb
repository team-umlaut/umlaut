require 'active_support'
require 'builder'
require 'chronic'

if not defined?(OAI::Const::VERBS)
  require 'oai/exception'
  require 'oai/constants'
  require 'oai/xpath'
  require 'oai/set'
end

%w{ response metadata_format resumption_token model partial_result
    response/record_response response/identify response/get_record
    response/list_identifiers response/list_records 
    response/list_metadata_formats response/list_sets response/error
  }.each { |lib| require File.dirname(__FILE__) + "/provider/#{lib}" }
  
if defined?(ActiveRecord)
  require File.dirname(__FILE__) + "/provider/model/activerecord_wrapper"
  require File.dirname(__FILE__) + "/provider/model/activerecord_caching_wrapper"
end

# = OAI::Provider
#
# Open Archives Initiative - Protocol for Metadata Harvesting see 
# http://www.openarchives.org/ 
#
# == Features
# * Easily setup a simple repository
# * Simple integration with ActiveRecord
# * Dublin Core metadata format included
# * Easily add addition metadata formats
# * Adaptable to any data source
# * Simple resumption token support
#
# == Usage
#
# To create a functional provider either subclass Provider::Base, 
# or reconfigure the defaults.
# 
# === Sub classing a provider
#
#  class MyProvider < Oai::Provider
#    repository_name 'My little OAI provider'
#    repository_url  'http://localhost/provider'
#    record_prefix 'oai:localhost'
#    admin_email 'root@localhost'   # String or Array
#    source_model MyModel.new       # Subclass of OAI::Provider::Model
#  end
#
# === Configuring the default provider
#
#  class Oai::Provider::Base
#    repository_name 'My little OAI Provider'
#    repository_url 'http://localhost/provider'
#    record_prefix 'oai:localhost'
#    admin_email 'root@localhost'
#    source_model MyModel.new
#  end
#
# The provider does allow a URL to be passed in at request processing time
# in case the repository URL cannot be determined ahead of time.
#
# == Integrating with frameworks
#
# === Camping
#
# In the Models module of your camping application post model definition:
# 
#   class CampingProvider < OAI::Provider::Base
#     repository_name 'Camping Test OAI Repository'
#     source_model ActiveRecordWrapper.new(YOUR_ACTIVE_RECORD_MODEL)
#   end
#
# In the Controllers module:
#
#   class Oai
#     def get
#       @headers['Content-Type'] = 'text/xml'
#       provider = Models::CampingProvider.new
#       provider.process_request(@input.merge(:url => "http:"+URL(Oai).to_s))
#     end
#   end
#
# The provider will be available at "/oai"
#
# === Rails
#
# At the bottom of environment.rb create a OAI Provider:
#
#   # forgive the standard blog example.
# 
#   require 'oai'
#   class BlogProvider < OAI::Provider::Base
#     repository_name 'My little OAI Provider'
#     repository_url 'http://localhost:3000/provider'
#     record_prefix 'oai:blog'
#     admin_email 'root@localhost'
#     source_model OAI::Provider::ActiveRecordWrapper.new(Post)
#   end
#
# Create a custom controller:
#
#   class OaiController < ApplicationController
#     def index
#       # Remove controller and action from the options.  Rails adds them automatically.
#       options = params.delete_if { |k,v| %w{controller action}.include?(k) }
#       provider = BlogProvider.new
#       response =  provider.process_request(options)
#       render :text => response, :content_type => 'text/xml'
#     end
#   end
#
# Special thanks to Jose Hales-Garcia for this solution. 
#
# == Supporting custom metadata formats
#
# See Oai::Metadata for details.
# 
# == ActiveRecord Integration
#
# ActiveRecord integration is provided by the ActiveRecordWrapper class.
# It takes one required paramater, the class name of the AR class to wrap,
# and optional hash of options.
#
# Valid options include:
# * timestamp_field - Specifies the model field to use as the update
#   filter.  Defaults to 'updated_at'.
# * limit -           Maximum number of records to return in each page/set.
#   Defaults to 100.  The wrapper will paginate the result via resumption tokens.  
#   Caution:  specifying too large a limit will adversely affect performance.
# 
# Mapping from a ActiveRecord object to a specific metadata format follows
# this set of rules:
#
# 1. Does Model#to_{metadata_prefix} exist?  If so just return the result.
# 2. Does the model provide a map via Model.map_{metadata_prefix}?  If so
#    use the map to generate the xml document.
# 3. Loop thru the fields of the metadata format and check to see if the
#    model responds to either the plural, or singular of the field.
#
# For maximum control of the xml metadata generated, it's usually best to
# provide a 'to_{metadata_prefix}' in the model.  If using Builder be sure
# not to include any instruct! in the xml object.
#  
# === Explicit creation example 
#
#  class Post < ActiveRecord::Base
#    def to_oai_dc
#      xml = Builder::XmlMarkup.new
#      xml.tag!("oai_dc:dc", 
#        'xmlns:oai_dc' => "http://www.openarchives.org/OAI/2.0/oai_dc/",
#        'xmlns:dc' => "http://purl.org/dc/elements/1.1/",
#        'xmlns:xsi' => "http://www.w3.org/2001/XMLSchema-instance",
#        'xsi:schemaLocation' => 
#          %{http://www.openarchives.org/OAI/2.0/oai_dc/ 
#            http://www.openarchives.org/OAI/2.0/oai_dc.xsd}) do
#          xml.tag!('oai_dc:title', title)
#          xml.tag!('oai_dc:description', text)
#          xml.tag!('oai_dc:creator', user)
#          tags.each do |tag|
#            xml.tag!('oai_dc:subject', tag)
#          end
#      end
#      xml.target!
#    end
#  end  
#
# === Mapping Example
#
#  # Extremely contrived mapping
#  class Post < ActiveRecord::Base
#    def self.map_oai_dc
#      {:subject => :tags, 
#       :description => :text, 
#       :creator => :user, 
#       :contibutor => :comments}
#    end
#  end
#
module OAI::Provider
  class Base
    include OAI::Provider
    
    class << self
      attr_reader :formats
      attr_accessor :name, :url, :prefix, :email, :delete_support, :granularity, :model

      def register_format(format)
        @formats ||= {}
        @formats[format.prefix] = format
      end
      
      def format_supported?(prefix)
        @formats.keys.include?(prefix)
      end
      
      def format(prefix)
        @formats[prefix]
      end

      protected 
      
      def inherited(klass)
        self.instance_variables.each do |iv|
          klass.instance_variable_set(iv, self.instance_variable_get(iv))
        end
      end

      alias_method :repository_name,    :name=
      alias_method :repository_url,     :url=
      alias_method :record_prefix,      :prefix=
      alias_method :admin_email,        :email=
      alias_method :deletion_support,   :delete_support=  
      alias_method :update_granularity, :granularity=     
      alias_method :source_model,       :model=
      
    end

    # Default configuration of a repository
    Base.repository_name 'Open Archives Initiative Data Provider'
    Base.repository_url 'unknown'
    Base.record_prefix 'oai:localhost'
    Base.admin_email 'nobody@localhost'
    Base.deletion_support OAI::Const::Delete::TRANSIENT
    Base.update_granularity OAI::Const::Granularity::HIGH

    Base.register_format(OAI::Provider::Metadata::DublinCore.instance)
    
    # Equivalent to '&verb=Identify', returns information about the repository
    def identify(options = {})
      Response::Identify.new(self.class, options).to_xml
    end

    # Equivalent to '&verb=ListSets', returns a list of sets that are supported
    # by the repository or an error if sets are not supported.
    def list_sets(options = {})
      Response::ListSets.new(self.class, options).to_xml
    end
    
    # Equivalent to '&verb=ListMetadataFormats', returns a list of metadata formats
    # supported by the repository.
    def list_metadata_formats(options = {})
      Response::ListMetadataFormats.new(self.class, options).to_xml
    end

    # Equivalent to '&verb=ListIdentifiers', returns a list of record headers that 
    # meet the supplied criteria.
    def list_identifiers(options = {})
      Response::ListIdentifiers.new(self.class, options).to_xml
    end
    
    # Equivalent to '&verb=ListRecords', returns a list of records that meet the 
    # supplied criteria.
    def list_records(options = {})
      Response::ListRecords.new(self.class, options).to_xml
    end
    
    # Equivalent to '&verb=GetRecord', returns a record matching the required
    # :identifier option 
    def get_record(options = {})
      Response::GetRecord.new(self.class, options).to_xml
    end
    
    #  xml_response = process_verb('ListRecords', :from => 'October', 
    #    :until => 'November') # thanks Chronic!
    #
    # If you are implementing a web interface using process_request is the
    # preferred way.
    def process_request(params = {})
      begin

        # Allow the request to pass in a url
        self.class.url = params['url'] ? params.delete('url') : self.class.url
          
        verb = params.delete('verb') || params.delete(:verb)
        
        unless verb and OAI::Const::VERBS.keys.include?(verb)
          raise OAI::VerbException.new
        end
          
        send(methodize(verb), params) 

      rescue => err
        if err.respond_to?(:code)
          Response::Error.new(self.class, err).to_xml
        else
          raise err
        end
      end
    end
    
    # Convert valid OAI-PMH verbs into ruby method calls
    def methodize(verb)
      verb.gsub(/[A-Z]/) {|m| "_#{m.downcase}"}.sub(/^\_/,'')
    end
    
  end
  
end
