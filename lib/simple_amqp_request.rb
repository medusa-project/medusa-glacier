require 'json'
class SimpleAmqpRequest < Object

  attr_accessor :json_request, :request_hash, :is_valid

  def initialize(json_request)
    self.json_request = json_request
    self.request_hash = JSON.parse(json_request)
    self.is_valid = true
  rescue JSON::ParserError
    self.request_hash = {}
    self.is_valid = false
  end

  def action
    self.request_hash['action']
  end

  def parameter(key)
    self.request_hash['parameters'][key.to_s]
  end

  def pass_through
    self.request_hash['pass_through'] || Hash.new
  end

  def raw_request
    self.json_request
  end

  def is_valid?
    self.is_valid
  end

end