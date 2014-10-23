class SimpleAmqpResponse < Object

  attr_accessor :response_hash

  def initialize
    self.response_hash = Hash.new
    self.pass_through = Hash.new
  end

  def to_json
    self.response_hash.to_json
  end

  def pass_through=(hash)
    response_hash[:pass_through] = hash
  end

  def action=(action)
    response_hash[:action] = action
  end

  def error_message=(message)
    response_hash[:message] = message
  end

  def be_failure
    response_hash[:status] = 'failure'
  end

  def be_success
    response_hash[:status] = 'success'
  end

  def set_parameter(key, value)
    self.response_hash[key] = value
  end

  def fail_unrecognized_action(action)
    be_failure
    self.action = action
    self.error_message = 'Unrecognized Action'
  end

  def fail_request_parse_error(raw_request)
    be_failure
    self.error_message = 'Invalid Request'
    self.set_parameter(:raw_request, raw_request)
  end

  def fail_unknown
    be_failure
    self.error_message = 'Unknown failure'
  end

  def succeed(action, parameter_hash = {})
    be_success
    self.action = action
    self.response_hash['parameters'] = parameter_hash
  end

end