# spotter
This project is focused on providing opportunities for implementing workers and middleware layers for AMQP queues which are actively used in you system. Workers as middlewares will help you to restrict an access to the certain message queues and doing pre-processing or validating data before passing it later to the next queue in the processing chain. 

For example, it's very important for a cases when you should guaranteed that the data on each stage of pipeline will be correct and valid so that the last stage will send a response to the client as expected, instead of let it crash at some stage without sending a detailed error.

# Features
- Restricting an access to the certain message queues (or resources) via checking permissions
- Pre-processing an input data before passing it to the next stage

# Installing

The package can be installed via adding the `spotter` dependency to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:spotter, "~> 0.1.2"}]
  end
  ```

# Configuration

By default Spotter reads environment configuration and trying to establish a AMQP connection with the following parameters:

  * `SPOTTER_AMQP_USERNAME` - username. Default: `guest`
  * `SPOTTER_AMQP_PASSWORD` - password. Default: `guest`
  * `SPOTTER_AMQP_HOST` - host. Default: `localhost`
  * `SPOTTER_AMQP_PORT` - port. Default: `5672`
  * `SPOTTER_AMQP_VHOST` - default virtual host. Default: `/`
  * `SPOTTER_AMQP_TIMEOUT` - timeout, Default: `60000` milliseconds.
 
Also it is possible to specify other connections that can be found in [AMQP client docs](https://hexdocs.pm/amqp/AMQP.Connection.html#open/1). 
Any of those arguments (that were mentioned in the documentation) can be specified in `GenServer.start_link/3` function.

# Example

  ```elixir
  defmodule CustomWorker do
    use Spotter.Worker

    @exchange "amqp.direct"
    @queue_validate "validate.queue"
    @queue_genstage "genstage.queue"

    # Specify here a router that will be using during processing a message
    @router Spotter.Router.new([
      {"my.test.endpoint", ["get", "post"]},
    ])

    def configure(connection, _config) do
      {:ok, channel} = AMQP.Channel.open(connection)
      :ok = AMQP.Exchange.direct(channel, @exchange, durable: true)

      # An initial point where the worker do required stuff
      {:ok, queue_request} = AMQP.Queue.declare(channel, @queue_validate, durable: true, auto_delete: true)
      :ok = AMQP.Queue.bind(channel, @queue_validate, @exchange, routing_key: @queue_validate)

      # Queue for a valid messages
      {:ok, queue_forward} = AMQP.Queue.declare(channel, @queue_genstage, durable: true, auto_delete: true)
      :ok = AMQP.Queue.bind(channel, @queue_genstage, @exchange, routing_key: @queue_genstage)

      # Specify a consumer here
      :ok = AMQP.Basic.qos(channel, prefetch_count: 1)
      {:ok, _} = AMQP.Basic.consume(channel, @queue_validate)

      # The second element will be storing in state[:meta]
      {:ok, [channel: channel, queue_request: queue_request, queue_forward: queue_forward]}
    end

    # Invoked when a message successfully consumed
    def handle_info({:basic_deliver, payload, %{delivery_tag: tag, reply_to: reply_to, headers: headers}}, state) do
      channel = state[:meta][:channel]
      spawn fn -> consume(channel, tag, reply_to, headers, payload) end
      {:noreply, state}
    end
        
    # Processing a consumed message
    defp consume(channel, tag, reply_to, headers, payload) do
      # Do some usefull stuff here ...

      # And don't forget to ack a processed message. Or perhaps even use nack 
      # when it will be neceessary.
      AMQP.Basic.ack(channel, tag)
    end
  end
  ```
  
  Pay attention to this `consume/5` method. I recommend to send async messages to GenServer that will be consumed later, so that when the message is processing a single thread wouldn't be blocked.  
  After that just specify this `CustomWorker` in your OTP application with supervisor and invoke `GenServer.start_link/3`.
