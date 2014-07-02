#!/usr/bin/env ruby

require 'bunny'
require 'json'

class Test

  attr_accessor :connection, :channel, :exchange

  def initialize
    self.connection = Bunny.new
    self.connection.start
    self.channel = self.connection.create_channel
    self.exchange = self.channel.default_exchange
  end

  def send_request
    request = {action: 'upload_directory', parameters: {directory: '/home/hading/tmp/upload', description: 'Test upload'},
               pass_through: {x: 'x', y: 'y'}}
    self.exchange.publish(request.to_json, :routing_key => 'medusa_to_glacier', :persistent => true)
  end

  def get_response
    queue = self.channel.queue('glacier_to_medusa', durable: true)
    delivery_info, properties, payload = queue.pop
    return delivery_info, properties, payload
  end
end

