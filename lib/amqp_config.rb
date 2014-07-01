class AmqpConfig
  cattr_accessor :incoming_queue, :outgoing_queue

  def self.initialize
    self.config = YAML.load_file('config/amqp.yaml')
    self.incoming_queue = config['incoming_queue']
    self.outgoing_queue = config['outgoing_queue']
  end
end

AmqpConfig.initialize
