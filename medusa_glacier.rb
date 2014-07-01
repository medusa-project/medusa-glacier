#!/usr/bin/env ruby
require 'java'
require 'yaml'
require 'eventmachine'
require 'logging'
require 'bunny'
require 'json'

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

require_relative 'lib/amazon_config'
require_relative 'lib/amqp_config'

class MedusaGlacier

  attr_accessor :logger, :outgoing_queue, :incoming_queue

  def initialize
    initialize_logger
    initialize_amqp
  end

  def initialize_logger
#To get started, start up a server that just reads requests from the queue and logs them
    self.logger = Logging.logger['medusa_glacier']
    self.logger.add_appenders(Logging.appenders.file('log/medusa_glacier.log', :layout => Logging.layouts.pattern(:pattern => '[%d] %-5l: %m\n')))
    self.logger.level = :info
    self.logger.info 'Starting server'
    ['log', 'run'].each { |directory| FileUtils.mkdir_p(directory) }
  end

  def initialize_amqp
    amqp_connection = Bunny.new
    amqp_connection.start
    channel = amqp_connection.create_channel
    self.incoming_queue = channel.queue(AmqpConfig.incoming_queue, :durable => true)
    #This call is just to make sure that this queue exists
    self.outgoing_queue = channel.queue(AmqpConfig.outgoing_queue, :durable => true)
  end

  def run
    EventMachine.run do
      Kernel.at_exit do
        self.logger.info 'Stopping server'
      end
      self.incoming_queue.subscribe do |delivery_info, metadata, request|
        self.logger.info "Got message: #{request}"
        #Write request to system
        #service request
        #remove request from system
        #reply to request
      end
    end
  end

end

MedusaGlacier.new.run