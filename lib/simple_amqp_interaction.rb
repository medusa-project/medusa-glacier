require_relative 'simple_amqp_request'
require_relative 'simple_amqp_response'
require 'uuid'

class SimpleAmqpInteraction < Object

  attr_accessor :uuid, :request, :response

  def initialize(json_request, uuid = nil)
    self.uuid = uuid || UUID.generate
    self.response = SimpleAmqpResponse.new
    #TODO - handle JSON parse failure here
    self.request = SimpleAmqpRequest.new(json_request)
    self.response.pass_through = self.request_pass_through
  end

  def action
    self.request.action
  end

  def request_parameter(key)
    self.request.parameter(key.to_s)
  end

  def request_pass_through
    self.request.pass_through
  end

  def raw_request
    self.request.raw_request
  end

  def fail_unrecognized_action
    self.response.fail_unrecognized_action(self.action)
  end

  def fail_request_parse_error(raw_request)
    self.response.fail_request_parse_error(raw_request)
  end

  def fail_unknown
    self.response.fail_unknown
  end

  def succeed(action, parameter_hash)
    self.response.succeed(action, parameter_hash)
  end

end