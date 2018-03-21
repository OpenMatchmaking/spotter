defmodule Spotter.AMQP.Connection.Helper do
  @moduledoc """
  Helper functions to manage connections with AMQP.

  This module produces verbose debug logs.
  """
  use AMQP
  require Logger

  # Default settings for AMQP connection.
  @defaults [
    username: {:system, "SPOTTER_AMQP_USER", "guest"},
    password: {:system, "SPOTTER_AMQP_PASSWORD", "guest"},
    host: {:system, "SPOTTER_AMQP_HOST", "localhost"},
    port: {:system, :integer, "SPOTTER_AMQP_PORT", 5672},
    virtual_host: {:system, "SPOTTER_AMQP_VHOST", "/"},
    connection_timeout: {:system, :integer, "SPOTTER_AMQP_TIMEOUT", 60_000},
  ]

  @doc """
  Open AMQP connection.

  # Options
    * `:username` - The name of a user registered with the broker (defaults to \"guest\");
    * `:password` - The password of user (defaults to \"guest\");
    * `:virtual_host` - The name of a virtual host in the broker (defaults to \"/\");
    * `:host` - The hostname of the broker (defaults to \"localhost\");
    * `:port` - The port the broker is listening on (defaults to `5672`);
    * `:channel_max` - The channel_max handshake parameter (defaults to `0`);
    * `:frame_max` - The frame_max handshake parameter (defaults to `0`);
    * `:heartbeat` - The hearbeat interval in seconds (defaults to `0` - turned off);
    * `:connection_timeout` - The connection timeout in milliseconds (defaults to `15_000`);
    * `:ssl_options` - Enable SSL by setting the location to cert files (defaults to `none`);
    * `:client_properties` - A list of extra client properties to be sent to the server, defaults to `[]`;
    * `:socket_options` - Extra socket options. These are appended to the default options. \
                          See http://www.erlang.org/doc/man/inet.html#setopts-2 \
                          and http://www.erlang.org/doc/man/gen_tcp.html#connect-4 \
                          for descriptions of the available options.

  See: https://hexdocs.pm/amqp/AMQP.Connection.html#open/1
  """
  def open_connection!(connection_opts) do
    case open_connection(connection_opts) do
      {:ok, %Connection{} = connection} -> connection
      {:error, message} -> raise message
    end
  end

  @doc """
  Same as `open_connection!/1`, but returns {:ok, connection} or {:error, reason} tuples.
  """
  def open_connection(connection_opts) do
    Logger.debug "Establishing new AMQP connection, with opts: #{inspect connection_opts}"

    connection = @defaults
    |> Keyword.merge(connection_opts)
    |> env
    |> Connection.open

    case connection do
      {:ok, %Connection{}} = res ->
        res
      {:error, :not_allowed} ->
        Logger.error "AMQP refused connection, opts: #{inspect connection_opts}"
        {:error, "AMQP vhost not allowed"}
      {:error, :econnrefused} ->
        Logger.error "AMQP refused connection, opts: #{inspect connection_opts}"
        {:error, "AMQP connection was refused"}
      {:error, :timeout} ->
        Logger.error "AMQP connection timeout, opts: #{inspect connection_opts}"
        {:error, "AMQP connection timeout"}
      {:error, {:auth_failure, message}} ->
        Logger.error "AMQP authorization failed, opts: #{inspect connection_opts}"
        {:error, "AMQP authorization failed: #{inspect message}"}
      {:error, reason} ->
        Logger.error "Error during AMQP connection establishing, opts: #{inspect connection_opts}"
        {:error, inspect(reason)}
    end
  end

  @doc """
  Open new AMQP channel inside a connection.

  See: https://hexdocs.pm/amqp/AMQP.Channel.html#open/1
  """
  def open_channel!(%Connection{} = connection) do
    case open_channel(connection) do
      {:ok, %Channel{} = channel} -> channel
      {:error, message} -> raise message
    end
  end

  @doc """
  Same as `open_channel!/1`, but returns {:ok, connection} or {:error, reason} tuples.
  """
  def open_channel(%Connection{} = connection) do
    Logger.debug "Opening new AMQP channel for connection #{inspect connection.pid}"
    case Process.alive?(connection.pid) do
      true -> _open_channel(connection)
      false -> {:error, :conn_dead}
    end
  end

  defp _open_channel(connection) do
    case Channel.open(connection) do
      {:ok, %Channel{} = channel} ->
        {:ok, channel}
      :closing ->
        Logger.debug "Channel is closing, retry.."
        :timer.sleep(1_000)
        open_channel(connection)
      {:error, reason} ->
        Logger.error "Can't create new AMQP channel"
        {:error, inspect(reason)}
    end
  end

  @doc """
  Gracefully close AMQP channel.
  """
  def close_channel(%Channel{} = channel) do
    Logger.debug "Closing AMQP channel"
    Channel.close(channel)
  end

  @doc """
  Set channel QOS policy. Especially useful when you want to limit number of
  unacknowledged request per worker.

  # Options
    * `:prefetch_size` - Limit of unacknowledged messages (in bytes).
    * `:prefetch_count` - Limit of unacknowledged messages (count).
    * `:global` - If `global` is set to `true` this applies to the \
                  entire Connection, otherwise it applies only to the specified Channel.

  See: https://hexdocs.pm/amqp/AMQP.Basic.html#qos/2
  """
  def set_channel_qos(%Channel{} = channel, opts) do
    Logger.debug "Changing channel QOS to #{inspect opts}"
    Basic.qos(channel, env(opts))
    channel
  end

  @doc """
  Declare AMQP queue. You can omit `error_queue`, then dead letter queue won't be created.
  Dead letter queue is hardcoded to be durable.

  # Options
    * `:durable` - If set, keeps the Queue between restarts of the broker
    * `:auto-delete` - If set, deletes the Queue once all subscribers disconnect
    * `:exclusive` - If set, only one subscriber can consume from the Queue
    * `:passive` - If set, raises an error unless the queue already exists

  See: https://hexdocs.pm/amqp/AMQP.Queue.html#declare/3
  """
  def declare_queue(%Channel{} = channel, queue, error_queue, opts) when is_binary(error_queue) and error_queue != "" do
    Logger.debug "Declaring new queue '#{queue}' with dead letter queue '#{error_queue}'. Options: #{inspect opts}"
    opts =
      [arguments: [
        {"x-dead-letter-exchange", :longstr, ""},
        {"x-dead-letter-routing-key", :longstr, error_queue}
      ]]
      |> Keyword.merge(opts)
      |> env()

    Queue.declare(channel, env(error_queue), durable: true)
    Queue.declare(channel, env(queue), opts)
    channel
  end

  def declare_queue(%Channel{} = channel, queue, _, opts) do
    Logger.debug "Declaring new queue '#{queue}' without dead letter queue. Options: #{inspect opts}"
    Queue.declare(channel, env(queue), env(opts))
    channel
  end

  @doc """
  Declare AMQP exchange. Exchange is durable whenever queue is durable.

  # Types:
    *   `:direct` - direct exchange.
    *   `:fanout` - fanout exchange.
    *   `:topic` - topic exchange.
    *   `:headers` - headers exchange.

  See: https://hexdocs.pm/amqp/AMQP.Queue.html#declare/3
  """
  def declare_exchange(%Channel{} = channel, exchange, type \\ :direct, opts \\ []) do
    Logger.debug "Declaring new exchange '#{exchange}' of type '#{inspect type}'. Options: #{inspect opts}"
    Exchange.declare(channel, env(exchange), env(type), env(opts))
    channel
  end

  @doc """
  Bind AMQP queue to Exchange.

  See: https://hexdocs.pm/amqp/AMQP.Queue.html#bind/4
  """
  def bind_queue(%Channel{} = channel, queue, exchange, opts) do
    Logger.debug "Binding new queue '#{queue}' to exchange '#{exchange}'. Options: #{inspect opts}"
    Queue.bind(channel, env(queue), env(exchange), env(opts))
    channel
  end

  defp env(var) do
    Confex.resolve_env!(var)
  end
end
