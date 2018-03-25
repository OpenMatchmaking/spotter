# spotter
This project is focused on providing opportunities for implementing workers and middleware layers for AMQP queues which are actively used in you system. Workers as middlewares will help you to restrict an access to the certain message queues and doing pre-processing or validating data before passing it later to the next queue in the processing chain. 

For example, it's very important for a cases when you should guaranteed that the data on each stage of pipeline will be correct and valid so that the last stage will send a response to the client as expected, instead of let it crash at some stage without sending a detailed error.

# Features
- Restricting an access to the certain message queues (or resources) via checking permissions
- Pre-processing an input data before passing it to the next stage
- Monitoring and re-establishing failed AMQP connections

# Installing

The package can be installed via adding the `spotter` dependency to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:spotter, "~> 0.2.2"}]
  end
  ```

add the `:spotter` application to the extra_applications:

  ```elixir
  def application do
    [extra_applications: [:spotter]]
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

# Examplee

  1. Define a connection module which is going be used later 

  ```elixir
  defmodule AppAMQPConnection do
    use Spotter.AMQP.Connection,
    otp_app: :custom_app
    # You can specify here queue, exchange and QoS parameters when it necessary.
    # However, will be better to store a configuration per each worker separately.
  end
  ```

  2. Implement your own worker, like here
  
  ```elixir
  defmodule CustomWorker do
    use Spotter.Worker,
    connection: AppAMQPConnection

    # Also you could specify here the `queue` \ `exchange` \ `qos` options
    # instead of instantiating and binding the @queue_validate queue manually.
    # For more details see: https://github.com/Nebo15/rbmq

    @exchange "amqp.direct"
    @queue_validate "validate.queue"
    @queue_genstage "genstage.queue"

    # Specify here a router that will be using during processing a message
    @router Spotter.Router.new([
      {"my.test.endpoint", ["get", "post"]},
    ])

    # Specify here the queue that you want to use
    def configure(channel, _config) do
      :ok = AMQP.Exchange.direct(channel, @exchange, durable: true)

      # An initial point where the worker do required stuff
      {:ok, queue_request} = AMQP.Queue.declare(channel, @queue_validate, durable: true, auto_delete: true)
      :ok = AMQP.Queue.bind(channel, @queue_validate, @exchange, routing_key: @queue_validate)

      # Queue for a valid messages
      {:ok, queue_forward} = AMQP.Queue.declare(channel, @queue_genstage, durable: true, auto_delete: true)
      :ok = AMQP.Queue.bind(channel, @queue_genstage, @exchange, routing_key: @queue_genstage)

      # Specify a consumer here
      {:ok, _} = AMQP.Basic.consume(channel, @queue_validate)

      # And dont forget to return the channel
      {:ok, channel}
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

  3. Add the connection with the worker to your application

  ```elixir
  defmodule CustomApp do
    use Application

    # For more detail see: http://elixir-lang.org/docs/stable/elixir/Application.html
    def start(_type, _args) do
      import Supervisor.Spec, warn: false

      # Define workers and child supervisors to be supervised
      children = [
        supervisor(AppAMQPConnection, []),
        worker(CustomWorker, []),
      ]

      opts = [strategy: :one_for_one, name: CustomAppSupervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ``` 

# Thanks
This package is heavily inspired and built on the top of the RBMQ package. The orignal project is published under the MIT license and you can find the source code [here](https://github.com/Nebo15/rbmq).
