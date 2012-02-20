# encoding: UTF-8

# A library to create and parse NISO Z39.88 OpenURLs
# Can also work with OpenURL 0.1, but your YMMV
# See:  http://alcme.oclc.org/openurl/docs/implementation_guidelines/
# for more information on implementing NISO Z39.88

require 'date'
require 'rexml/document'
require 'cgi'
require 'openurl/context_object'
require 'openurl/context_object_entity'
require 'openurl/transport'

Dir.open(File.dirname(File.expand_path(__FILE__))+'/openurl/metadata_formats').each do | file |
  next if file.match(/^\./)
  class_name = file.sub(/\.rb$/,'')
  require "openurl/metadata_formats/#{class_name}"
end
