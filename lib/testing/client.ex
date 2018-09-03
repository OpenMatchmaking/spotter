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
  """
  def send(pid, data, opts, call_timeout \\ 5000) do
    GenServer.call(pid, {:send, data, opts}, call_timeout)
  end

  @doc """
  Sends a new message and wait for result.
  """
  def send_and_wait(pid, data, opts, timeout \\ 1000, attempts \\ 5, call_timeout \\ 5000) do
    GenServer.call(pid, {:send_and_wait, data, opts, timeout, attempts}, call_timeout)
  end

  @doc """
  Returns the message from the certain queue if it exists.
  """
  def consume(pid, queue, timeout \\ 1000, attempts \\ 5, call_timeout \\ 500) do
    GenServer.call(pid, {:consume_response, queue, timeout, attempts}, call_timeout)
  end

  @doc """
  Initializes QoS, a queue and an exchanges for the channel.
  """
  def configure_channel(pid, channel_opts, call_timeout \\ 500) do
    GenServer.call(pid, {:configure_channel, channel_opts}, call_timeout)
  end

  # Internal stuff

  defp send_message(channel, routing_key, data, opts) do
    exchange_request = Keyword.get(opts, :exchange_request, "")
    queue_request = Keyword.get(opts, :queue_request, "")
    publish_options = Keyword.merge(opts, [
      persistent: Keyword.get(opts, :persistent, true),
      reply_to: routing_key,
      content_type: Keyword.get(opts, :content_type, "application/json")
    ])
    AMQP.Basic.publish(channel, exchange_request, queue_request, data, publish_options)
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
    {:reply, send_message(state[:channel], :undefined, data, opts), state}
  end

  def handle_call({:send_and_wait, data, opts, timeout, attempts}, _from, state) do
    channel = state[:channel]
    channel_opts = state[:channel_opts]
    queue_name = Keyword.get(channel_opts[:queue] || [], :name, :undefined)
    routing_key = Keyword.get(channel_opts[:queue] || [], :routing_key, :undefined)

    configure(channel, channel_opts)
    send_message(channel, routing_key, data, opts)
    response = consume_response(state[:channel], queue_name, timeout, attempts)

    AMQP.Queue.delete(channel, queue_name)
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