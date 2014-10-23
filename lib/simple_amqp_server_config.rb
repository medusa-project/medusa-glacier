require 'yaml'
class SimpleAmqpServerConfig < Object

  attr_accessor :config

  def initialize(config_file)
    self.config = YAML.load_file(config_file)
  end

  #use this to enable query of top level keys via a method call with args for further arguments. Return nil if
  #the top level key is present but the specific config setting is not. Raise an error if the top level key is
  #not present
  def method_missing(name, *args)
    if h = self.config[name.to_s]
      self.find_value(h, args)
    else
      raise
    end
  end

  #Descend into a multilevel hash to extract a value or nil.
  def find_value(hash_or_value, args)
    if args.empty?
      hash_or_value
    else
      new_hash_or_value = hash_or_value[args.shift.to_s]
      new_hash_or_value ? find_value(new_hash_or_value, args) : nil
    end
  end

  def server_name
    self.server(:name) || (raise NotImplementedError, 'You must define the server.name configuration key')
  end

end