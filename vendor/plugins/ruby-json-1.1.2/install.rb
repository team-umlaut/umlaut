#! /usr/bin/env ruby
# Install Script
#  Copyright (C) 2003 Rafael R. Sevilla <dido@imperium.ph>
#  This file is part of JSON for Ruby
#
#  JSON for Ruby is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public License
#  as published by the Free Software Foundation; either version 2.1 of
#  the License, or (at your option) any later version.
#
#  JSON for Ruby is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details. 
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with JSON for Ruby; if not, write to the Free
#  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
#  02111-1307 USA.
#
# Author:: Rafael R. Sevilla (mailto:dido@imperium.ph)
# Copyright:: Copyright (c) 2003 Rafael R. Sevilla
# License:: GNU Lesser General Public License
# $Id: install.rb,v 1.1 2003/08/20 10:53:24 didosevilla Exp $
#

require 'getoptlong'
require 'ftools'
require 'find'

SOURCE_DIR = 'json'
LIBDIR = 'json'

def instdir
    g = GetoptLong.new(['--install-dir', '-i', GetoptLong::REQUIRED_ARGUMENT])
    g.each { | name, arg |
	if name == '--install-dir'
	    return arg
	else
	    $stderr.puts "usage: $0 [--install-dir dir]"
	end
    }

    begin
	require 'rbconfig'
	libdir = Config::CONFIG['sitedir'] + "/" + 
	    Config::CONFIG['MAJOR'] + "." +
	    Config::CONFIG['MINOR']
    rescue ScriptError
	$LOAD_PATH.each do |l|
	    if l =~ /site_ruby/ && l =~ /\d$/ && l !~ /#{PLATFORM}/
		libdir = l
		break
	    end
	end
	STDERR.puts "Can't find required file `rbconfig.rb'."
	STDERR.puts "The 'json' files need to be installed manually in " +
	    " #{libdir}"
    end
    return libdir
end

INSTALL_DIR = instdir()
File.makedirs(File.join(INSTALL_DIR, LIBDIR))
Find.find(SOURCE_DIR) { |f|
    File.install(f, File.join(INSTALL_DIR, f), 0644, true) if f =~ /.rb$/
}
