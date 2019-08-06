defmodule SpotterTestingAmqpBlockingClientTest do
  use ExUnit.Case, async: false
  alias Spotter.Testing.AmqpBlockingClient

  @generic_exchange "test.direct"
  @queue_name "blocking_client_test"

  @custom_amqp_opts [
    username: "user",
    password: "password",
    host: "rabbitmq",
    port: 5672,
    virtual_host: "/",
    queue: [
      name: @queue_name,
      routing_key: @queue_name,
      durable: true,
      passive: false,
      auto_delete: true
    ],
    exchange: [
      name: @generic_exchange,
      type: :direct,
      durable: true,
      passive: true
    ],
    qos: [
      prefetch_count: 10
    ]
  ]

  setup do
    {:ok, pid} = start_supervised({AmqpBlockingClient, @custom_amqp_opts})
    {:ok, [client: pid]}
  end

  test "AMQP blocking client sends the message and consumes the message from the queue", state do
    client = state[:client]
    message = "test"
    AmqpBlockingClient.configure_channel(client, @custom_amqp_opts)

    send_result = AmqpBlockingClient.send(
      client, message,
      [queue_request: @queue_name, exchange_request: @generic_exchange]
    )
    assert send_result == :ok

    {response, _meta} = AmqpBlockingClient.consume(client, @queue_name)
    assert response == message

    stop_supervised(client)
  end

  test "AMQP blocking client consumes the message from the queue and returns empty results", state do
    client = state[:client]
    AmqpBlockingClient.configure_channel(client, @custom_amqp_opts)

    {:empty, nil} = AmqpBlockingClient.consume(client, @queue_name, 1, 100)
    stop_supervised(client)
  end

  test "AMQP blocking client sends the message and waits for the response", state do
    client = state[:client]
    message = "test"

    channel_options = Keyword.merge(
      @custom_amqp_opts,
      [queue_request: @queue_name, exchange_request: @generic_exchange]
    )
    {response, _meta} = AmqpBlockingClient.send_and_wait(client, message, channel_options)
    assert response == message

    stop_supervised(client)
  end

  test "AMQP blocking client receive {:empty, nil} by timeout for consuming messages", state do
    client = state[:client]
    AmqpBlockingClient.configure_channel(client, @custom_amqp_opts)

    {response, meta} = AmqpBlockingClient.consume(client, @queue_name, 100, 1, 1)
    assert response == :empty
    assert meta == nil

    stop_supervised(client)
  end
end
