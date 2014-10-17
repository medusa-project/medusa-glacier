require 'java'
require 'yaml'
require 'logging'
require 'bunny'
require 'json'
require 'uuid'
require 'fileutils'
require 'base64'
require 'date'

require_relative 'amazon_config'
require_relative 'amqp_config'

import com.amazonaws.services.glacier.transfer.ArchiveTransferManager
import com.amazonaws.services.glacier.transfer.UploadResult
import com.amazonaws.services.glacier.model.DeleteArchiveRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsRequest
import com.amazonaws.services.glacier.model.ListMultipartUploadsResult
import com.amazonaws.services.glacier.model.AbortMultipartUploadRequest

class MedusaGlacierServer

  attr_accessor :logger, :outgoing_queue, :incoming_queue, :channel, :request_directory, :halt_before_processing,
                :config

  def initialize
    initialize_logger
    initialize_amqp
    initialize_config
    self.halt_before_processing = false
    self.request_directory = 'run/active_requests'
  end

  def initialize_config
    self.config = YAML.load_file('config/glacier_server.yaml')
  end

  def cfs_root
    self.config['cfs_root']
  end

  def bag_root
    self.config['bag_root']
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
    self.channel = amqp_connection.create_channel
    self.incoming_queue = self.channel.queue(AmqpConfig.incoming_queue, :durable => true)
    #This call is just to make sure that this queue exists
    self.outgoing_queue = self.channel.queue(AmqpConfig.outgoing_queue, :durable => true)
  end

  def run
    Kernel.at_exit do
      self.logger.info 'Stopping server'
    end
    Kernel.trap('USR2') do
      self.halt_before_processing = !self.halt_before_processing
      self.logger.info "Server will halt before processing next job: #{self.halt_before_processing}"
      puts "Server will halt before processing next job: #{self.halt_before_processing}"
    end
    handle_saved_requests
    while true do
      delivery_info, metadata, request = self.incoming_queue.pop
      if request
        self.service_incoming_request(request)
      else
        sleep 60
      end
    end
  end

  def shutdown
    self.logger.info "Halting server before processing request."
    puts "Halting server before processing request."
    exit 0
  end

  def handle_saved_requests
    Dir[File.join(self.request_directory, '*-*')].each do |file|
      request = File.read(file)
      uuid = File.basename(file)
      self.logger.info "Restarting Request: #{uuid}\n#{request}"
      service_request(request, uuid)
      self.shutdown if self.halt_before_processing
    end
  end

  def service_incoming_request(request)
    uuid = UUID.generate
    self.logger.info "Started Request: #{uuid}\n#{request}"
    #Write request to system
    FileUtils.mkdir_p(self.request_directory)
    File.open(File.join(self.request_directory, uuid), 'w') { |f| f.puts request }
    service_request(request, uuid)
    self.shutdown if self.halt_before_processing
  end

  def service_request(request, uuid)
    response_hash = self.dispatch_and_handle_request(request)
    #remove request from system
    FileUtils.rm(File.join(request_directory, uuid))
    self.outgoing_queue.channel.default_exchange.publish(response_hash.to_json, :routing_key => self.outgoing_queue.name, :persistent => true)
    self.logger.info "Finished Request: #{uuid}"
  end

  #deal with the request and return a hash to be used when messaging the client
  def dispatch_and_handle_request(request)
    json_request = JSON.parse(request)
    case json_request['action']
      when 'upload_directory'
        handle_upload_directory_request(json_request)
      else
        return {:status => 'failure', :error_message => 'Unrecognized Action', :action => json_request['action'],
            :pass_through => json_request['pass_through']}
    end
  rescue JSON::ParserError
    return {:status => 'failure', :error_message => 'Invalid Request', :pass_through => json_request['pass_through']}
  rescue Exception => e
    logger.error "Unknown Error: #{e.to_s}"
    return {:status => 'failure', :error_message => 'Unknown failure', :pass_through => json_request['pass_through']}
  end

  #maybe dispatch some of the following depending on whether this is a full or incremental backup
  #clean up any previous attempt to service request
  #construct bag
  #tar bag
  #upload tar
  #remove tar and bag
  #Additionally this should be refactored, it's messy
  def handle_upload_directory_request(json_request)
    self.logger.info "In handle upload"
    relative_directory = json_request['parameters']['directory']
    source_directory = File.join(self.cfs_root, relative_directory)
    unless File.directory?(source_directory)
      return {:status => 'failure', :error_message => 'Upload directory not found', :action => json_request['action'], :pass_through => json_request['pass_through']}
    end
    ingest_id = relative_directory.gsub('/', '-')
    bag_directory = File.join(self.bag_root, ingest_id)
    tar_file = File.join(self.bag_root, "#{ingest_id}.tar")
    FileUtils.rm(tar_file) if File.exists?(tar_file)
    FileUtils.rm_rf(bag_directory) if File.exists?(bag_directory)
    date = json_request['parameters']['date']
    if date
      date = Date.parse(date) if date
      make_incremental_tar(source_directory, bag_directory, tar_file, date)
    else
      make_full_tar(source_directory, bag_directory, tar_file)
    end
    Dir.chdir(bag_directory) do
      #system('tar', '--create', '--file', tarball_name, File.basename(source_directory))
      transfer_manager = ArchiveTransferManager.new(AmazonConfig.glacier_client, AmazonConfig.aws_credentials)
      self.logger.info "Doing upload"
      self.logger.info "Vault: #{AmazonConfig.vault_name}"
      self.logger.info "Tarball: #{tar_file} Bytes: #{File.size(tar_file)}"
      #There are problems if the description has certain characters - it can only have ascii 0x20-0x7f by Amazon specification,
      #and it seems to have problems with ':' as well using this API, so we deal with it simply by base64 encoding it.
      encoded_description = Base64.strict_encode64(json_request['parameters']['description'] || '')
      #It seems that when making the java file object we need to use the full path
      result = transfer_manager.upload(AmazonConfig.vault_name, encoded_description,
                                       java.io.File.new(File.join(tarball_directory, tarball_name)))
      self.logger.info "Archive uploaded with archive id: #{result.getArchiveId()}"
      self.logger.info "Removing tar"
      FileUtils.rm(tarball_name) if File.exists?(tar_file)
      self.logger.info "Removing bag directory"
      FileUtils.rm_rf(bag_directory) if File.exists?(bag_directory)
      return {:status => 'success', :action => json_request['action'], :pass_through => json_request['pass_through'],
          :parameters => {:archive_ids => [result.getArchiveId()]}}
    end
  end

  #This isn't directly in the current workflow, It's a convenience for testing, etc.
  def delete_archive(archive_id)
    delete_request = DeleteArchiveRequest.new
    delete_request.with_vault_name(AmazonConfig.vault_name)
    delete_request.with_archive_id(archive_id)
    AmazonConfig.glacier_client.delete_archive(delete_request)
  end

end
