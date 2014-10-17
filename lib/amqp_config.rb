class AmqpConfig
  cattr_accessor :incoming_queue, :outgoing_queue, :cfs_root

  def self.initialize
    self.config = YAML.load_file('config/amqp.yaml')
    self.incoming_queue = config['incoming_queue']
    self.outgoing_queue = config['outgoing_queue']
    self.cfs_root = config['cfs_root']
  end
end

AmqpConfig.initialize
