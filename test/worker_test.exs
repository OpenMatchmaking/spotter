defmodule SpotterWorkerTest do
  use ExUnit.Case
  use AMQP

  @generic_exchange "test.direct"
  @generic_queue_request "worker_test_queue_request"
  @generic_queue_forward "worker_test_queue_forward"

  @custom_amqp_opts [
    username: "user",
    password: "password",
    host: "rabbitmq",
    port: 5672,
    virtual_host: "/"
  ]

  defmodule CustomEndpoint do
    use Spotter.Endpoint.Base

    @enforce_keys [:path]
    defstruct [:path, permissions: []]

    def new(path, permissions) do
      %CustomEndpoint{path: path,  permissions: permissions}
    end

    def match(endpoint, path) do
      endpoint.path == path
    end

    def validate(_endpoint, data) do
      case String.equivalent?(data, "DATA") do
        true -> {:ok, data}
        false -> {:error, "VALIDATION_ERROR"}
      end
    end
  end

  defmodule CustomWorker do
    use Spotter.Worker

    @exchange "test.direct"
    @queue_request "worker_test_queue_request"
    @queue_forward "worker_test_queue_forward"

    @router Spotter.Router.new([
      {"api.matchmaking.search", ["get", "post"], CustomEndpoint},
    ])

    def configure(connection, _config) do
      {:ok, channel} = AMQP.Channel.open(connection)
      :ok = AMQP.Exchange.direct(channel, @exchange, durable: true, auto_delete: true)

      # An initial point where the worker do required stuff
      {:ok, queue_request} = AMQP.Queue.declare(channel, @queue_request, durable: true, auto_delete: true)
      :ok = AMQP.Queue.bind(channel, @queue_request, @exchange, routing_key: @queue_request)

      # Queue for a valid messages
      {:ok, queue_forward} = AMQP.Queue.declare(channel, @queue_forward, durable: true, auto_delete: true)
      :ok = AMQP.Queue.bind(channel, @queue_forward, @exchange, routing_key: @queue_forward)

      :ok = AMQP.Basic.qos(channel, prefetch_count: 1)
      {:ok, _} = AMQP.Basic.consume(channel, @queue_request)

      {:ok, [channel: channel, queue_request: queue_request, queue_forward: queue_forward]}
    end

    # Handle the trapped exit call
    def handle_info({:EXIT, _from, reason}, state) do
      {:stop, reason, state}
    end

    # Confirmation sent by the broker after registering this process as a consumer
    def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, state) do
      {:noreply, state}
    end

    # Sent by the broker when the consumer is unexpectedly cancelled
    def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, state) do
      {:stop, :normal, state}
    end

    # Confirmation sent by the broker to the consumer process after a Basic.cancel
    def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, state) do
      {:noreply, state}
    end

    # Invoked when a message successfully consumed
    def handle_info({:basic_deliver, payload, %{delivery_tag: tag, reply_to: reply_to, headers: headers}}, state) do
      channel = state[:meta][:channel]
      message_headers = Enum.into(Enum.map(headers, fn({key, _, value}) -> {key, value} end), %{})
      spawn fn -> consume(channel, tag, reply_to, message_headers, payload) end
      {:noreply, state}
    end

    # Processing a message
    defp consume(channel, tag, reply_to, headers, payload) do
      case Spotter.Router.dispatch(@router, headers["path"]) do
        endpoint when endpoint != nil ->
          permissions = String.split(headers["permissions"], ";", trim: true)
          case endpoint.__struct__.has_permission(endpoint, permissions) do
            true ->
              case endpoint.__struct__.validate(endpoint, payload) do
                {:ok, data} -> AMQP.Basic.publish(channel, @exchange, @queue_forward, data, persistent: true)
                {:error, reason} -> AMQP.Basic.publish(channel, @exchange, reply_to, reason, persistent: true)
              end
            false ->
              AMQP.Basic.publish(channel, @exchange, reply_to, "NO_PERMISSIONS", persistent: true)
          end
        nil -> AMQP.Basic.publish(channel, @exchange, reply_to, "INVALID_URL", persistent: true)
      end

      AMQP.Basic.ack(channel, tag)
    end
  end

  setup_all do
    {:ok, pid} = CustomWorker.start_link(@custom_amqp_opts)
    {:ok, [worker: pid]}
  end

  def create_client_connection() do
    AMQP.Connection.open(@custom_amqp_opts)
  end

  def create_response_queue(connection) do
    {:ok, channel} = AMQP.Channel.open(connection)
    :ok = AMQP.Exchange.direct(channel, @generic_exchange, passive: true)

    {:ok, queue} = AMQP.Queue.declare(channel, "", exclusive: true, durable: true, auto_delete: true)
    :ok = AMQP.Queue.bind(channel, queue[:queue], @generic_exchange, routing_key: queue[:queue])

    {:ok, channel, queue}
  end

  test "CustomWorker forwards message to the next queue", _state do
    {:ok, connection} = create_client_connection()
    {:ok, channel, queue} = create_response_queue(connection)

    :ok = AMQP.Basic.publish(channel, @generic_exchange, @generic_queue_request, "DATA",
                             persistent: true,
                             reply_to: queue[:queue],
                             headers: [{"path", :longstr, "api.matchmaking.search"},
                                       {"permissions", :longstr, "get;post"}]
    )
    :timer.sleep(100)
    {:ok, payload, %{delivery_tag: tag}} = AMQP.Basic.get(channel, @generic_queue_forward)
    assert payload == "DATA"

    AMQP.Basic.ack(channel, tag)
    AMQP.Connection.close(connection)
  end

  test "CustomWorker returns an error for not matched resources", _state do
    {:ok, connection} = create_client_connection()
    {:ok, channel, queue} = create_response_queue(connection)

    :ok = AMQP.Basic.publish(channel, @generic_exchange, @generic_queue_request, "DATA",
                             persistent: true,
                             reply_to: queue[:queue],
                             headers: [{"path", :longstr, "NOT_EXISTING_RESOURCE"}, ]
    )
    :timer.sleep(100)
    {:ok, payload, %{delivery_tag: tag}} = AMQP.Basic.get(channel, queue[:queue])
    assert payload == "INVALID_URL"

    AMQP.Basic.ack(channel, tag)
    AMQP.Connection.close(connection)
  end

  test "CustomWorker returns a validation error", _state do
    {:ok, connection} = create_client_connection()
    {:ok, channel, queue} = create_response_queue(connection)

    :ok = AMQP.Basic.publish(channel, @generic_exchange, @generic_queue_request, "INVALID_DATA",
                             persistent: true,
                             reply_to: queue[:queue],
                             headers: [{"path", :longstr, "api.matchmaking.search"},
                                       {"permissions", :longstr, "get;post"}]
    )
    :timer.sleep(100)
    {:ok, payload, %{delivery_tag: tag}} = AMQP.Basic.get(channel, queue[:queue])
    assert payload == "VALIDATION_ERROR"

    AMQP.Basic.ack(channel, tag)
    AMQP.Connection.close(connection)
  end

  test "CustomWorker returns an error for a request without required permissions", _state do
    {:ok, connection} = create_client_connection()
    {:ok, channel, queue} = create_response_queue(connection)

    :ok = AMQP.Basic.publish(channel, @generic_exchange, @generic_queue_request, "DATA",
                             persistent: true,
                             reply_to: queue[:queue],
                             headers: [{"path", :longstr, "api.matchmaking.search"},
                                       {"permissions", :longstr, ""}]
    )
    :timer.sleep(100)
    {:ok, payload, %{delivery_tag: tag}} = AMQP.Basic.get(channel, queue[:queue])
    assert payload == "NO_PERMISSIONS"

    AMQP.Basic.ack(channel, tag)
    AMQP.Connection.close(connection)
  end
end

