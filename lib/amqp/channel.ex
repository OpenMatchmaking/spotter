defmodule Spotter.AMQP.Connection.Channel do
  @moduledoc """
  AMQP channel server.

  Whenever connection gets rest channel reinitializes itself.
  """
  use GenServer
  require Logger
  alias Spotter.AMQP.Connection.Helper

  def start_link(opts, name) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc false
  def init(opts) do
    channel_opts = opts
    |> Keyword.delete(:channel)
    |> Keyword.delete(:connection)
    |> Keyword.get(:config, [])

    case Helper.open_channel(opts[:connection]) do
      {:ok, channel} ->
        configure(channel, channel_opts)
        Process.monitor(channel.pid)
        {:ok, [channel: channel, config: channel_opts, connection: opts[:connection]]}
      {:error, :conn_dead} ->
        Logger.warn "Connection #{inspect opts[:connection].pid} is dead, waiting for supervisor actions.."
        {:ok, [channel: nil, config: channel_opts, connection: nil]}
    end
  end

  defp configure(channel, channel_opts) do
    channel
    |> configure_qos(channel_opts[:qos])
    |> configure_queue(channel_opts[:queue])
    |> configure_exchange(channel_opts[:queue], channel_opts[:exchange])
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
    Helper.declare_queue(channel, queue_opts[:name], queue_opts[:error_name], queue_opts)
    channel
  end

  defp configure_exchange(channel, queue_opts, exchange_opts) when is_nil(queue_opts) or is_nil(exchange_opts) do
    channel
  end

  defp configure_exchange(channel, queue_opts, exchange_opts) do
    Helper.declare_exchange(channel, exchange_opts[:name], exchange_opts[:type], exchange_opts)
    Helper.bind_queue(channel, queue_opts[:name], exchange_opts[:name], routing_key: queue_opts[:routing_key])
    channel
  end

  @doc false
  def get(pid) do
    GenServer.call(pid, :get)
  end

  @doc false
  def close(pid) do
    GenServer.cast(pid, :close)
  end

  @doc false
  def reconnect(pid, connection) do
    Logger.warn "Channel received connection change event: #{inspect connection}"
    GenServer.call(pid, {:reconnect, connection})
  end

  @doc false
  def set_config(pid, config) do
    GenServer.call(pid, {:apply_config, config})
  end

  @doc """
  Returns current configuration of a channel.
  """
  def get_config(pid) do
    GenServer.call(pid, :get_config)
  end

  @doc """
  Run callback inside Channel GenServer and return result.
  Callback function should accept connection as first argument.
  """
  def run(pid, callback) do
    GenServer.call(pid, {:run, callback})
  end

  @doc false
  def handle_info({:DOWN, monitor_ref, :process, pid, reason}, state) do
    Logger.warn "AMQP channel #{inspect pid} went down with reason #{inspect reason}."
    Process.demonitor(monitor_ref, [:flush])
    GenServer.cast(self(), {:restart, reason})
    {:noreply, state}
  end

  @doc false
  def handle_cast({:restart, _reason}, state) do
    {:ok, state} = state
    |> Keyword.delete(:channel)
    |> init

    {:noreply, state}
  end

  @doc false
  def handle_cast(:close, state) do
    Helper.close_channel(state[:channel])
    {:stop, :normal, :ok}
  end

  @doc false
  def handle_call(:get, _from, state) do
    {:reply, state[:channel], state}
  end

  @doc false
  def handle_call(:get_config, _from, state) do
    {:reply, state[:config], state}
  end

  @doc false
  def handle_call({:reconnect, connection}, _from, state) do
    {:ok, state} = init([connection: connection, config: state[:config]])
    {:reply, :ok, state}
  end

  @doc false
  def handle_call({:apply_config, config}, _from, state) do
    channel = state[:channel]
    |> configure(config)

    {:reply, :ok, [
      channel: channel,
      config: Keyword.merge(state[:config], config),
      connection: state[:connection]
    ]}
  end

  @doc false
  def handle_call({:run, callback}, _from, state) when is_function(callback) do
    {:reply, callback.(state[:channel]), state}
  end
end
