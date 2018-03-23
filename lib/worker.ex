defmodule Spotter.Worker do
  @moduledoc """
  Base worker module that works with AMQP.
  """
  @doc """
  Create a link to worker process. Used in supervisors.
  """
  @callback start_link :: Supervisor.on_start

  @doc """
  Get queue status.
  """
  @callback status :: {:ok, %{consumer_count: integer, message_count: integer, queue: String.t()}} | {:error, String.t()}

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use GenServer
      use Confex, Keyword.delete(opts, :connection)
      require Logger

      @connection Keyword.get(opts, :connection) || @module_config[:connection]
      @channel_name String.to_atom("#{__MODULE__}.Channel")

      unless @connection do
        raise "You need to implement connection module and pass it in :connection option."
      end

      def start_link() do
        GenServer.start_link(__MODULE__, config(), name: __MODULE__)
      end

      def init(opts) do
        case Process.whereis(@connection) do
          nil ->
            # Connection doesn't exist, lets fail to recover later
            {:error, :noconn}
          _ ->
            @connection.spawn_channel(@channel_name)
            @connection.configure_channel(@channel_name, opts)

            channel = get_channel()
            |> configure(opts)

            {:ok, channel}
        end
      end

      def configure(channel, _opts) do
        channel
      end

      def validate_config!(config) do
        config
      end

      defp get_channel() do
        channel = @channel_name
        |> @connection.get_channel
      end

      def status() do
        GenServer.call(__MODULE__, :status)
      end

      def channel_config() do
        Spotter.AMQP.Connection.Channel.get_config(@channel_name)
      end

      def handle_call(:status, _from, channel) do
        safe_run fn(_) ->
          {:reply, AMQP.Queue.status(channel, channel_config()[:queue][:name]), channel}
        end
      end

      def safe_run(fun) do
        channel = get_channel()

        case !is_nil(channel) && Process.alive?(channel.pid) do
          true ->
            fun.(channel)
          _ ->
            Logger.warn("[GenQueue] Channel #{inspect @channel_name} is dead, waiting till it gets restarted")
            :timer.sleep(3_000)
            safe_run(fun)
        end
      end

      defoverridable [configure: 2, validate_config!: 1]
    end
  end
end
