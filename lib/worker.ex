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
        GenServer.start_link(__MODULE__, %{config: config(), opts: []})
      end

      def start_link(opts) do
        GenServer.start_link(__MODULE__, %{config: config(), opts: opts})
      end

      def init(opts) do
        {channel_name, updated_opts} = Keyword.pop(opts[:opts], :channel_name, @channel_name)
        opts = Map.put(opts, :opts, updated_opts)

        case Process.whereis(@connection) do
          nil ->
            # Connection doesn't exist, lets fail to recover later
            {:error, :noconn}
          _ ->
            @connection.spawn_channel(channel_name)
            @connection.configure_channel(channel_name, opts[:config])

            channel = get_channel(channel_name)
            {:ok, custom} = configure(channel_name, opts[:opts])
            {:ok, [channel: channel, channel_name: channel_name, meta: custom]}
        end
      end

      def configure(_channel_name, _opts) do
        {:ok, []}
      end

      def validate_config!(config) do
        config
      end

      def get_channel(channel_name) do
        @connection.get_channel(channel_name)
      end

      def status() do
        GenServer.call(__MODULE__, :status)
      end

      def channel_config(channel_name) do
        Spotter.AMQP.Connection.Channel.get_config(channel_name)
      end

      def handle_call(:status, _from, state) do
        safe_run(
          state[:channel],
          fn(channel) ->
            config = channel_config(state[:channel_name])
            {:reply, AMQP.Queue.status(channel, config[:queue][:name]), state}
          end
        )
      end

      def safe_run(channel_name, fun) do
        channel = get_channel(channel_name)

        case !is_nil(channel) && Process.alive?(channel.pid) do
          true ->
            fun.(channel)
          _ ->
            Logger.warn("[GenQueue] Channel #{inspect channel} is dead, waiting till it gets restarted")
            :timer.sleep(3_000)
            safe_run(channel_name, fun)
        end
      end

      defoverridable [configure: 2, validate_config!: 1]
    end
  end
end
