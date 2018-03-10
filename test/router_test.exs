defmodule SpotterRouterTest do
  use ExUnit.Case

  test "Spotter.Router contructor with empty endpoint list" do
    router = Spotter.Router.new([])

    assert router.endpoints == []
  end

  test "Spotter.Router contructor with default endpoints" do
    router = Spotter.Router.new([
      {"api.matchmaking.search", ["get"]},
      {"api.leaderboard.{count}", ["get"]},
    ])

    assert length(router.endpoints) == 2

    endpoint_plain = Enum.at(router.endpoints, 0)
    assert endpoint_plain.path == "api.matchmaking.search"
    assert endpoint_plain.permissions == ["get"]

    endpoint_dynamic = Enum.at(router.endpoints, 1)
    assert endpoint_dynamic.path == "api.leaderboard.{count}"
    assert endpoint_dynamic.permissions == ["get"]
    assert endpoint_dynamic.regex == ~r/^api.leaderboard.(?P<count>[^{}\/.]+)$/
  end

  test "Spotter.Router contructor with custom endpoints" do
    router = Spotter.Router.new([
      {"api.matchmaking.search", ["get"], Spotter.Endpoint.Plain},
      {"api.leaderboard.{count}", ["get"], Spotter.Endpoint.Dynamic},
    ])

    assert length(router.endpoints) == 2

    endpoint_plain = Enum.at(router.endpoints, 0)
    assert endpoint_plain.path == "api.matchmaking.search"
    assert endpoint_plain.permissions == ["get"]

    endpoint_dynamic = Enum.at(router.endpoints, 1)
    assert endpoint_dynamic.path == "api.leaderboard.{count}"
    assert endpoint_dynamic.permissions == ["get"]
    assert endpoint_dynamic.regex == ~r/^api.leaderboard.(?P<count>[^{}\/.]+)$/
  end

  test "Spotter.Router dispatch returns an endpoint for a match" do
    router = Spotter.Router.new([
      {"api.matchmaking.search", ["get"], Spotter.Endpoint.Plain},
      {"api.leaderboard.{count}", ["get"], Spotter.Endpoint.Dynamic},
    ])

    endpoint = Spotter.Router.dispatch(router, "api.matchmaking.search")
    assert endpoint != nil
    assert endpoint.path == "api.matchmaking.search"
    assert endpoint.permissions == ["get"]
  end

  test "Spotter.Router dispatch returns nil for not found endpoint" do
    router = Spotter.Router.new([
      {"api.matchmaking.search", ["get"], Spotter.Endpoint.Plain},
      {"api.leaderboard.{count}", ["get"], Spotter.Endpoint.Dynamic},
    ])

    endpoint = Spotter.Router.dispatch(router, "NOT_EXISTING_ENDPOINT_PATH")
    assert endpoint == nil
  end
end
