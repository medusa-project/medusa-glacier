#!/usr/bin/env ruby
require 'java'
require 'yaml'
require 'eventmachine'
require 'logging'
require 'bunny'
require 'daemons'
require 'fileutils'
require 'json'
require_relative 'lib/amazon_config'
require_relative 'lib/amqp_config'

require_relative 'aws-java-sdk-1.8.0/lib/aws-java-sdk-1.8.0.jar'
Dir[File.join('aws-java-sdk-1.8.0/third-party/**/*.jar')].each do |jar|
  require_relative jar
end

import com.amazonaws.auth.AWSCredentials
import com.amazonaws.auth.BasicAWSCredentials
import com.amazonaws.services.glacier.AmazonGlacierClient
import com.amazonaws.services.glacier.transfer.ArchiveTransferManager
import com.amazonaws.services.glacier.transfer.UploadResult
import com.amazonaws.services.sns.AmazonSNSClient
import com.amazonaws.services.sqs.AmazonSQSClient
import com.amazonaws.services.glacier.model.DeleteArchiveRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsResult
import com.amazonaws.services.glacier.model.AbortMultipartUploadRequest


#To get started, start up a server that just reads requests from the queue and logs them
logger = Logging.logger['medusa_glacier']
logger.add_appenders(Logging.appenders.file('log/medusa_glacier.log', :layout => Logging.layouts.pattern(:pattern => '[%d] %-5l: %m\n')))
logger.level = :info
logger.info 'Starting server'
['log', 'run'].each {|directory| FileUtils.mkdir_p(directory)}

EventMachine.run do
  Kernel.at_exit do
    logger.info 'Stopping server'
  end
  amqp_connection = Bunny.new
  amqp_connection.start
  channel = amqp_connection.create_channel
  incoming_queue = channel.queue(AmqpConfig.incoming_queue, :durable => true)
  #This call is just to make sure that this queue exists
  outgoing_queue = channel.queue(AmqpConfig.outgoing_queue, :durable => true)
  incoming_queue.subscribe do |delivery_info, metadata, request|
    logger.info "Got message: #{request}"
  end
end
