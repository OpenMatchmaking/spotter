defmodule Spotter.Testing.AmqpBlockingClient do
  @moduledoc """
  A blocking AMPQ client for testing purposes and simple RPC use cases.
  """
  use GenServer
  alias Spotter.AMQP.Connection.Helper

  @doc """
  Initializes a new blocking GenServer instance.
  """
  def start_link(opts, name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Initializes a new connection and a channel.
  """
  def init(opts) do
    {:ok, connection} = Helper.open_connection(opts)
    {:ok, channel} = Helper.open_channel(connection)

    {:ok, %{
      connection: connection,
      channel: channel,
      channel_opts: [
        queue: Keyword.get(opts, :queue, []),
        exchange: Keyword.get(opts, :exchange, []),
        qos: Keyword.get(opts, :qos, [])
      ]
    }}
  end

  defp deinit(connection, channel) do
    Helper.close_channel(channel)
    AMQP.Connection.close(connection)
  end

  defp configure(channel, channel_opts) do
      channel = configure_qos(channel, channel_opts[:qos])
      {channel, queue_opts} = configure_queue(channel, channel_opts[:queue])
      channel_opts = Keyword.merge(channel_opts, [queue: queue_opts])
      channel = configure_exchange(channel, channel_opts[:queue], channel_opts[:exchange])
      channel
  end

  defp configure_qos(channel, nil) do
    channel
  end

  defp configure_qos(channel, qos_opts) do
    Helper.set_channel_qos(channel, qos_opts)
    channel
  end

  defp configure_queue(channel, nil) do
    channel
  end

  defp configure_queue(channel, queue_opts) do
    {:ok, queue} = AMQP.Queue.declare(channel, env(queue_opts[:name]), env(queue_opts))

    queue_opts =
      if queue_opts[:name] == "" and queue_opts[:routing_key] == "" do
        Keyword.merge(queue_opts, [name:  queue[:queue], routing_key: queue[:queue]])
      else
        queue_opts
      end

    {channel, queue_opts}
  end

  defp configure_exchange(channel, queue_opts, exchange_opts) when is_nil(queue_opts) or is_nil(exchange_opts) do
    channel
  end

  defp configure_exchange(channel, queue_opts, exchange_opts) do
    Helper.declare_exchange(channel, exchange_opts[:name], exchange_opts[:type], exchange_opts)
    Helper.bind_queue(channel, queue_opts[:name], exchange_opts[:name], routing_key: queue_opts[:routing_key])
    channel
  end

  defp env(var) do
    Confex.Resolver.resolve!(var)
  end

  # Public API

  @doc """
  Stop the client and close the existing connection.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Sends a new message without waiting for a response.

  The `data` parameter represents a payload, added to the message body.
  The `opts` parameter represented as a keyword, that can contain keys:

    * `:request_exchange` - Exchange key, through which will be published message.
    * `:request_routing_key` - Routing key, used for pushing message to the certain queue.
    * `:mandatory` - If set, returns an error if the broker can't route the message to a queue (default `false`);
    * `:immediate` - If set, returns an error if the broker can't deliver te message to a consumer immediately (default `false`);
    * `:content_type` - MIME Content type;
    * `:content_encoding` - MIME Content encoding;
    * `:headers` - Custom message headers;
    * `:persistent` - Determines delivery mode. Messages marked as `persistent` and delivered to `durable` \
                      queues will be logged to disk;
    * `:correlation_id` - Application correlation identifier;
    * `:priority` - Message priority, ranging from 0 to 9;
    * `:reply_to` - Name of the reply queue;
    * `:expiration` - How long the message is valid (in milliseconds);
    * `:message_id` - Message identifier;
    * `:timestamp` - Timestamp associated with this message (epoch time);
    * `:type` - Message type (as a string);
    * `:user_id` - User ID. Validated by RabbitMQ against the active connection user;
    * `:app_id` - Publishing application ID.

  The `call_timeout` parameter determines maximum amount time in milliseconds before exit from the method by timeout.
  """
  def send(pid, data, opts, call_timeout \\ 5000) do
    GenServer.call(pid, {:send, data, opts}, call_timeout)
  end

  @doc """
  Sends a new message and wait for result.

  The `data` parameter represents a payload, added to the message body.
  The `opts` parameter represented as a keyword, that can contain keys:

    * `:request_exchange` - Exchange key, through which will be published message. Required.
    * `:request_routing_key` - Routing key, used for pushing message to the certain queue. Required.
    * `:response_queue` - The name of the queue which will be used for tracking responses. Required.
    * `:channel_opts` - Keyword list which is used for creating response queue and linking it with the exchange. Required.
    * `:mandatory` - If set, returns an error if the broker can't route the message to a queue (default `false`);
    * `:immediate` - If set, returns an error if the broker can't deliver te message to a consumer immediately (default `false`);
    * `:content_type` - MIME Content type;
    * `:content_encoding` - MIME Content encoding;
    * `:headers` - Custom message headers;
    * `:persistent` - Determines delivery mode. Messages marked as `persistent` and delivered to `durable` \
                      queues will be logged to disk;
    * `:correlation_id` - Application correlation identifier;
    * `:priority` - Message priority, ranging from 0 to 9;
    * `:reply_to` - Name of the reply queue;
    * `:expiration` - How long the message is valid (in milliseconds);
    * `:message_id` - Message identifier;
    * `:timestamp` - Timestamp associated with this message (epoch time);
    * `:type` - Message type (as a string);
    * `:user_id` - User ID. Validated by RabbitMQ against the active connection user;
    * `:app_id` - Publishing application ID.

  The `timeout` parameter determines amout of time before doing next attempt to extract the message.
  The `attemps` parameter determines the general amount of attempts to extract the message.
  The `call_timeout` parameter determines maximum amount time in milliseconds before exit from the method by timeout.
  """
  def send_and_wait(pid, data, opts, timeout \\ 1000, attempts \\ 5, call_timeout \\ 5000) do
    try do
      GenServer.call(pid, {:send_and_wait, data, opts, timeout, attempts}, call_timeout)
    catch
      :exit, _reason -> {:empty, nil}
    end
  end

  @doc """
  Returns the message from the certain queue if it exists.

  The `queue` parameter represents the name of the queue which will be used for tracking responses.
  The `timeout` parameter determines amout of time before doing next attempt to extract the message.
  The `attemps` parameter determines the general amount of attempts to extract the message.
  The `call_timeout` parameter determines maximum amount time in milliseconds before exit from the method by timeout.
  """
  def consume(pid, queue, timeout \\ 1000, attempts \\ 5, call_timeout \\ 5000) do
    try do
      GenServer.call(pid, {:consume_response, queue, timeout, attempts}, call_timeout)
    catch
      :exit, _reason -> {:empty, nil}
    end
  end

  @doc """
  Initializes QoS, a queue and an exchanges for the channel.

  The `channel_opts` parameters stores generic information about the response queue and the linked exchange.
  The `call_timeout` parameter determines maximum amount time in milliseconds before exit from the method by timeout.
  """
  def configure_channel(pid, channel_opts, call_timeout \\ 500) do
    GenServer.call(pid, {:configure_channel, channel_opts}, call_timeout)
  end

  # Internal stuff

  defp send_message(channel, data, opts) do
    request_exchange = Keyword.get(opts, :request_exchange, "")
    request_routing_key = Keyword.get(opts, :request_routing_key, "")
    response_queue = Keyword.get(opts, :response_queue, "")
    publish_options = Keyword.merge(opts, [
      persistent: Keyword.get(opts, :persistent, true),
      reply_to: response_queue,
      content_type: Keyword.get(opts, :content_type, "application/json")
    ])
    AMQP.Basic.publish(channel, request_exchange, request_routing_key, data, publish_options)
  end

  defp consume_response(channel, queue_name, timeout, attempts) do
    {payload, meta} = receive_message(channel, queue_name, timeout, attempts)

    if meta != nil do
      AMQP.Basic.ack(channel, meta.delivery_tag)
    end

    {payload, meta}
  end

  defp receive_message(channel, queue_name, timeout, attempts) do
    case AMQP.Basic.get(channel, queue_name) do
      {:ok, message, meta} ->
        {message, meta}
      {:empty, _} when is_integer(attempts) and attempts == 0 ->
        {:empty, nil}
      {:empty, _} when is_integer(attempts) and attempts > 0 ->
        :timer.sleep(timeout)
        receive_message(channel, queue_name, timeout, attempts - 1)
    end
  end

  # Private API

  def handle_call({:send, data, opts}, _from, state) do
    {:reply, send_message(state[:channel], data, opts), state}
  end

  def handle_call({:send_and_wait, data, opts, timeout, attempts}, _from, state) do
    channel = state[:channel]
    channel_opts = state[:channel_opts]
    response_queue = Keyword.get(opts, :response_queue, "")

    configure(channel, channel_opts)
    send_message(channel, data, opts)
    response = consume_response(state[:channel], response_queue, timeout, attempts)

    if response_queue != "" do
      AMQP.Queue.delete(channel, response_queue)
    end

    {:reply, response, state}
  end

  def handle_call({:consume_response, queue, timeout, attempts}, _from, state) do
    {:reply, consume_response(state[:channel], queue, timeout, attempts), state}
  end

  def handle_call({:configure_channel, channel_opts}, _from, state) do
    configure(state[:channel], channel_opts)
    {:reply, :ok, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    deinit(state[:connection], state[:channel])
    {:noreply, state}
  end
end
