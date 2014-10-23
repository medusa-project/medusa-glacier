require 'json'
class SimpleAmqpRequest < Object

  attr_accessor :json_request, :request_hash

  def initialize(json_request)
    self.json_request = json_request
    self.request_hash = JSON.parse(json_request)
  end

  def action
    self.request_hash['action']
  end

  def parameter(key)
    self.request_hash['parameters'][key.to_s]
  end

  def pass_through
    self.request_hash['pass_through']
  end

  def raw_request
    self.json_request
  end

end