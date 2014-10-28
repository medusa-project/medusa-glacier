require 'logging'
require 'bunny'
require 'fileutils'
require_relative 'simple_amqp_server_config'
require_relative 'simple_amqp_interaction'

class SimpleAmqpServer < Object

  attr_accessor :logger, :config, :outgoing_queue, :incoming_queue, :channel, :halt_before_processing

  def initialize(args = {})
    initialize_config(args[:config_file])
    initialize_logger
    initialize_amqp
    self.halt_before_processing = false
  end

  def config_class
    SimpleAmqpServerConfig
  end

  def initialize_config(config_file)
    self.config = self.config_class.new(config_file)
  end

  def initialize_logger
    #To get started, start up a server that just reads requests from the queue and logs them
    self.logger = Logging.logger[config.server_name]
    self.logger.add_appenders(Logging.appenders.file(self.log_file, :layout => Logging.layouts.pattern(:pattern => '[%d] %-5l: %m\n')))
    self.logger.level = :info
    self.logger.info 'Starting server'
    [self.log_directory, self.run_directory, self.request_directory].each { |directory| FileUtils.mkdir_p(directory) }
  end

  def log_directory
    'log'
  end

  def log_file
    File.join('log', "#{config.server_name}.log")
  end

  def run_directory
    'run'
  end

  def request_directory
    File.join('run', "#{config.server_name}_active_requests")
  end

  def initialize_amqp
    amqp_connection = Bunny.new(config.amqp(:connection) || {})
    amqp_connection.start
    self.channel = amqp_connection.create_channel
    self.incoming_queue = self.channel.queue(config.amqp(:incoming_queue), :durable => true)
    self.outgoing_queue = self.channel.queue(config.amqp(:outgoing_queue), :durable => true)
  end

  def run
    Kernel.at_exit do
      self.logger.info 'Stopping server'
    end
    Kernel.trap('USR2') do
      self.halt_before_processing = !self.halt_before_processing
      logger_tee "Server will halt before processing next job: #{self.halt_before_processing}"
    end
    service_saved_requests
    while true do
      delivery_info, metadata, request = self.incoming_queue.pop
      if request
        self.service_incoming_request(request)
      else
        sleep self.sleep_on_empty_time
      end
    end
  end

  def shutdown
    logger_tee "Halting server before processing request."
    exit 0
  end

  def logger_tee(message)
    logger.info message
    puts message
  end

  def sleep_on_empty_time
    config.server(:sleep_on_empty) || 60
  end

  def service_saved_requests
    Dir[File.join(self.request_directory, '*-*')].each do |file|
      interaction = SimpleAmqpInteraction.new(File.read(file), File.basename(file))
      self.logger.info "Restarting Request: #{interaction.uuid}\n#{interaction.raw_request}"
      service_request(interaction)
      shutdown if halt_before_processing
    end
  end

  def service_incoming_request(request)
    interaction = SimpleAmqpInteraction.new(request)
    logger.info "Started Request: #{interaction.uuid}\n#{request}"
    persist_request(interaction)
    service_request(interaction)
    shutdown if halt_before_processing
  end

  def persist_request(interaction)
    FileUtils.mkdir_p(request_directory)
    File.open(File.join(request_directory, interaction.uuid), 'w') { |f| f.puts interaction.raw_request }
  end

  def unpersist_request(interaction)
    file = File.join(request_directory, interaction.uuid)
    FileUtils.rm(file) if File.exists?(file)
  end

  def service_request(interaction)
    if interaction.failed_request_parse?
      logger.error "Bad Request: #{interaction.raw_request}"
    else
      dispatch_and_handle_request(interaction)
    end
    unpersist_request(interaction)
    outgoing_queue.channel.default_exchange.publish(interaction.response.to_json, :routing_key => outgoing_queue.name, :persistent => true)
    logger.info "Finished Request: #{interaction.uuid}"
  end

  def dispatch_and_handle_request(interaction)
    handler_name = "handle_#{interaction.action}_request"
    if respond_to?(handler_name)
      send(handler_name, interaction)
    else
      interaction.fail_unrecognized_action
    end
  rescue Exception => e
    logger.error "Unknown Error: #{e.to_s}"
    interaction.fail_unknown
  end

end