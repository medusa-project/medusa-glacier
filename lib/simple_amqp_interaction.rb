require_relative 'simple_amqp_request'
require_relative 'simple_amqp_response'
require 'uuid'
require 'json'

class SimpleAmqpInteraction < Object

  attr_accessor :uuid, :request, :response

  def initialize(json_request, uuid = nil)
    self.uuid = uuid || UUID.generate
    self.response = SimpleAmqpResponse.new
    self.request = SimpleAmqpRequest.new(json_request)
    self.response.pass_through = self.request_pass_through || Hash.new
    self.fail_request_parse_error(self.raw_request) unless self.request.is_valid?
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

  def fail_generic(error_message)
    self.response.fail_generic(self.action, error_message)
  end

  def invalid_request?
    self.response.invalid_request?
  end

  def succeed(parameter_hash)
    self.response.succeed(self.action, parameter_hash)
  end

  def failed_request_parse?
    self.response.invalid_request?
  end

end