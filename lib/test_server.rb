#This is a really simple example of how you can implement a server. It has a single action, 'square', which requires
#a single numeric parameter 'number' and returns the square of that number.

require_relative 'simple_amqp_server'

class TestServer < SimpleAmqpServer

  def handle_square_request(interaction)
    number = interaction.request_parameter('number')
    interaction.succeed(square: number * number)
  end

end
