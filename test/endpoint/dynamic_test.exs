defmodule SpotterEndpointDynamicTest do
  use ExUnit.Case

  test "Spotter.Endpoint.Dynamic contructor set permissions to empty list" do
    endpoint = Spotter.Endpoint.Dynamic.new("api.leaderboard.get.{user_id}", [])

    assert endpoint.regex == ~r/^api.leaderboard.get.(?P<user_id>[^{}\/.]+)$/
    assert endpoint.base.path == "api.leaderboard.get.{user_id}"
    assert endpoint.base.permissions == []
  end

  test "Spotter.Endpoint.Dynamic contructor with custom permissions" do
    endpoint = Spotter.Endpoint.Dynamic.new(
      "api.leaderboard.get.{user_id}",
      ["api.leaderboard.get"]
    )

    assert endpoint.regex == ~r/^api.leaderboard.get.(?P<user_id>[^{}\/.]+)$/
    assert endpoint.base.path == "api.leaderboard.get.{user_id}"
    assert endpoint.base.permissions == ["api.leaderboard.get", ]
  end

  test "Spotter.Endpoint.Dynamic.match returns true for exact match" do
    endpoint = Spotter.Endpoint.Dynamic.new(
      "api.leaderboard.get.{user_id}",
      ["api.leaderboard.get", ]
    )

    assert Spotter.Endpoint.Dynamic.match(endpoint, "api.leaderboard.get.user-123456789")
  end

  test "Spotter.Endpoint.Dynamic.match returns false for not matched path" do
    endpoint = Spotter.Endpoint.Dynamic.new(
      "api.leaderboard.get.{user_id}",
      ["api.leaderboard.get", ]
    )

    assert not Spotter.Endpoint.Dynamic.match(endpoint, "some.another.api")
  end

  test "Spotter.Endpoint.Dynamic.has_permission returns true for correct permissions" do
    endpoint = Spotter.Endpoint.Dynamic.new("api.leaderboard.get.{user_id}", ["get", "update"])

    assert Spotter.Endpoint.Dynamic.has_permissions(endpoint, ["get", "update", "delete"])
  end

  test "Spotter.Endpoint.Dynamic.has_permission returns false for invalid permissions" do
    endpoint = Spotter.Endpoint.Dynamic.new("api.leaderboard.get.{user_id}", ["list", "delete"])

    assert not Spotter.Endpoint.Dynamic.has_permissions(endpoint, ["list", "update"])
  end

  test "Spotter.Endpoint.Dynamic.has_permission returns true for the endpoint without permissions" do
    endpoint = Spotter.Endpoint.Dynamic.new("api.leaderboard.get.{user_id}", [])

    assert Spotter.Endpoint.Dynamic.has_permissions(endpoint, ["get", "patch", "head"])
  end
end
