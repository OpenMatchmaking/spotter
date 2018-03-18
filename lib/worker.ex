defmodule Spotter.Worker do
  @moduledoc """
  Base worker module that works with AMQP.
  """
  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do

      use GenServer
      use AMQP
      require Logger

      @defaults [
        username: {:system, "SPOTTER_AMQP_USERNAME", "guest"},
        password: {:system, "SPOTTER_AMQP_PASSWORD", "guest"},
        host: {:system, "SPOTTER_AMQP_HOST", "localhost"},
        port: {:system, :integer, "SPOTTER_AMQP_PORT", 5672},
        virtual_host: {:system, "SPOTTER_AMQP_VHOST", "/"},
        connection_timeout: {:system, :integer, "SPOTTER_AMQP_TIMEOUT", 60_000},
      ]

      # Client callbacks

      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, [])
      end

      # Server callbacks

      defp open_connection(opts) do
        case AMQP.Connection.open(opts) do
          {:ok, connection} ->
            {:ok, connection}
          {:error, reason} ->
            Logger.error "An error occurred during connection establishing: #{inspect reason}"
            :timer.sleep(@defaults[:connection_timeout])
            open_connection(opts)
        end
      end

      @doc """
      Post-initialization method for a worker. Specify here exchanges, queues and so on.
      """
      def configure(connection, _config) do
        {:ok, []}
      end

      def init(opts) do
        Process.flag(:trap_exit, true)

        config = @defaults
          |> Keyword.merge(opts)
          |> Confex.Resolver.resolve!

        {:ok, connection} = open_connection(config)
        Process.monitor(connection.pid)

        {:ok, meta} = configure(connection, config)
        {:ok, [connection: connection, config: config, meta: meta]}
      end

      def handle_info({:DOWN, _monitor_ref, :process, _pid, _reason}, state) do
        old_connection = state[:connection]

        {:ok, connection} = open_connection(state[:config])
        {:noreply, [connection: connection, config: state[:config], meta: state[:meta]]}
      end

      defoverridable [configure: 2]
    end
  end
end
