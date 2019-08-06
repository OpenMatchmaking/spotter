defmodule SpotterTestingAmqpBlockingClientTest do
  use ExUnit.Case, async: false
  alias Spotter.Testing.AmqpBlockingClient

  @generic_exchange "test.direct"
  @queue_name "blocking_client_test"
  @secondary_queue_name "secondary_queue"

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

  @secondary_amqp_opts [
    username: "user",
    password: "password",
    host: "rabbitmq",
    port: 5672,
    virtual_host: "/",
    queue: [
      name: @secondary_queue_name,
      routing_key: @secondary_queue_name,
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
    {:ok, client} = start_supervised({AmqpBlockingClient, @custom_amqp_opts})
    AmqpBlockingClient.configure_channel(client, @custom_amqp_opts)
    AmqpBlockingClient.configure_channel(client, @secondary_amqp_opts)
    {:ok, [client: client]}
  end

  test "AMQP blocking client sends the message and consumes the message from the queue", state do
    client = state[:client]
    message = "test"

    send_result = AmqpBlockingClient.send(
      client, message,
      [
        request_exchange: @generic_exchange,
        request_routing_key: @queue_name
      ]
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

    opts = Keyword.merge(
      @custom_amqp_opts,
      [
        request_exchange: @generic_exchange,
        request_routing_key: @queue_name,
        response_queue: @queue_name
      ]
    )
    {response, _meta} = AmqpBlockingClient.send_and_wait(client, message, opts)
    assert response == message

    stop_supervised(client)
  end

  test "AMQP blocking client receive {:empty, nil} by timeout for consuming messages", state do
    client = state[:client]

    {response, meta} = AmqpBlockingClient.consume(client, @queue_name, 100, 1, 1)
    assert response == :empty
    assert meta == nil

    stop_supervised(client)
  end

  test "AMQP blocking client receive {:empty, nil} by timeout for sent_and_wait call", state do
    client = state[:client]
    message = "test"

    opts = Keyword.merge(
      @custom_amqp_opts,
      [
        request_exchange: @generic_exchange,
        request_routing_key: @queue_name,
        response_queue: @secondary_queue_name
      ]
    )
    {response, meta} = AmqpBlockingClient.send_and_wait(client, message, opts, 100)
    assert response == :empty
    assert meta == nil

    {response_2, _meta_2} = AmqpBlockingClient.consume(client, @queue_name, 100)
    assert response_2 == message
    stop_supervised(client)
  end

  test "AMQP blocking client receive message with custom headers", state do
    client = state[:client]
    message = "test"

    opts = Keyword.merge(
      @custom_amqp_opts,
      [
        request_exchange: @generic_exchange,
        request_routing_key: @queue_name,
        response_queue: @queue_name,
        headers: [
          om_permissions: "matchmaking.test.test; matchmaking.test.api",
          om_request_url: "/api/v1/matchmaking/search",
        ]
      ]
    )
    {response, meta} = AmqpBlockingClient.send_and_wait(client, message, opts, 100)
    assert response == message
    assert meta[:headers] == [
      {"om_permissions", :longstr, "matchmaking.test.test; matchmaking.test.api"},
      {"om_request_url", :longstr, "/api/v1/matchmaking/search"}
    ]

    stop_supervised(client)
  end
end
