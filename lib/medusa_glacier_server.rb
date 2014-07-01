require 'java'
require 'yaml'
require 'eventmachine'
require 'logging'
require 'bunny'
require 'json'
require 'uuid'

require_relative 'amazon_config'
require_relative 'amqp_config'

import com.amazonaws.services.glacier.transfer.ArchiveTransferManager
import com.amazonaws.services.glacier.transfer.UploadResult
import com.amazonaws.services.glacier.model.DeleteArchiveRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsResult
import com.amazonaws.services.glacier.model.AbortMultipartUploadRequest

class MedusaGlacierServer

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
        self.service_request(request)
      end
    end
  end

  def service_request(request)
    uuid = UUID.generate
    self.logger.info "Started Request: #{uuid}\n#{request}"
    #Write request to system
    request_directory = 'run/active_requests'
    FileUtils.mkdir_p(request_directory)
    File.open(File.join(request_directory, uuid), 'w') {|f| f.puts request}
    #TODO service request
    sleep 30
    #remove request from system
    FileUtils.rm(File.join(request_directory, uuid))
    #reply to request
    self.logger.info "Finished Request: #{uuid}"
  end

end
