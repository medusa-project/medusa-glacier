#!/usr/bin/env ruby
require_relative 'lib/medusa_glacier_server'

#only run if given run as the first argument. This is useful for letting us load this file
#in irb to work with things interactively when we need to
MedusaGlacierServer.new(config_file: 'config/glacier_server.yaml').run if ARGV[0] == 'run'