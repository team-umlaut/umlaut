require 'zlib'
require 'net/smtp'
require 'yaml'
require 'tempfile'
require 'logger'
require 'fileutils'
require 'ostruct'
require 'readline'
require 'chronic'
require 'socket'

require 'oai/harvester/config'
require 'oai/harvester/harvest'
require 'oai/harvester/logging'
require 'oai/harvester/mailer'
require 'oai/harvester/shell'

def harvestable_sites(conf)
  sites = []
  conf.sites.each do |k, v|
    sites << k if needs_updating(v['period'], v['last'])
  end if conf.sites
  sites
end

def needs_updating(period, last)
  return true if last.nil?
  case period
  when 'daily'
    return true if Time.now - last > 86000
  when 'weekly'
    return true if Time.now - last > 604000
  when 'monthly'
    return true if Time.now - last > 2591000
  end
  return false
end

