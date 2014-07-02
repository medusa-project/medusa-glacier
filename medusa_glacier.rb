#!/usr/bin/env ruby
require 'java'
require_relative 'aws-java-sdk-1.8.0/lib/aws-java-sdk-1.8.0.jar'
Dir[File.join('aws-java-sdk-1.8.0/third-party/**/*.jar')].each do |jar|
  require_relative jar
end

require 'lib/medusa_glacier_server'

#only run if given run as the first argument. This is useful for letting us load this file
#in irb to work with things interactively when we need to
MedusaGlacierServer.new.run if ARGV[0] == 'run'