#!/usr/bin/env ruby
#
# Created by William Groppe on 2007-02-01.
#
# Simple file based Model.  Basically just serves a directory of xml files to the
# Provider.
#
class File
  def id
    File.basename(self.path)
  end
  
  def to_oai_dc
    self.read
  end
end
    
class FileModel < OAI::Provider::Model
  include OAI::Provider
  
  def initialize(directory = 'data')
    # nil specifies no partial results aka resumption tokens, and 'mtime' is the
    # method that the provider will call for determining the timestamp
    super(nil, 'mtime')
    @directory = directory
  end
  
  def earliest
    e = Dir["#{@directory}/*.xml"].min { |a,b| File.stat(a).mtime <=> File.stat(b).mtime }
    File.stat(e).mtime.utc.xmlschema
  end
  
  def latest
    e = Dir["#{@directory}/*.xml"].max { |a,b| File.stat(a).mtime <=> File.stat(b).mtime }
    File.stat(e).mtime.utc.xmlschema
  end

  def sets
    nil
  end
  
  def find(selector, opts={})
    return nil unless selector

    case selector
    when :all
      records = Dir["#{@directory}/*.xml"].sort.collect do |file|
        File.new(file) unless File.stat(file).mtime.utc < opts[:from] or
          File.stat(file).mtime.utc > opts[:until]
      end
      records
    else
      Find.find("#{@directory}/#{selector}") rescue nil
    end
  end
  
end

# == Example Usage:
# class FileProvider < OAI::Provider::Base
#   repository_name 'XML File Provider'
#   source_model FileModel.new('/tmp')
# end