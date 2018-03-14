defmodule SpotterEndpointPlainTest do
  use ExUnit.Case

  test "Spotter.Endpoint.Plain contructor set permissions to empty list" do
    endpoint = Spotter.Endpoint.Plain.new("api.matchmaking.search", [])

    assert endpoint.base.path == "api.matchmaking.search"
    assert endpoint.base.permissions == []
  end

  test "Spotter.Endpoint.Plain contructor with custom permissions" do
    endpoint = Spotter.Endpoint.Plain.new("api.matchmaking.search", ["api.search.retrieve"])

    assert endpoint.base.path == "api.matchmaking.search"
    assert endpoint.base.permissions == ["api.search.retrieve", ]
  end

  test "Spotter.Endpoint.Plain.match returns true for exact match" do
    endpoint = Spotter.Endpoint.Plain.new("api.matchmaking.search", ["api.search.retrieve"])

    assert Spotter.Endpoint.Plain.match(endpoint, "api.matchmaking.search")
  end

  test "Spotter.Endpoint.Plain.match returns false for not matched path" do
    endpoint = Spotter.Endpoint.Plain.new("api.matchmaking.search", ["get"])

    assert not Spotter.Endpoint.Plain.match(endpoint, "some.another.api")
  end

  test "Spotter.Endpoint.Plain.has_permission returns true for correct permissions" do
    endpoint = Spotter.Endpoint.Plain.new("api.matchmaking.search", ["get", "update"])

    assert Spotter.Endpoint.Plain.has_permissions(endpoint, ["get", "update", "delete"])
  end

  test "Spotter.Endpoint.Plain.has_permission returns false for invalid permissions" do
    endpoint = Spotter.Endpoint.Plain.new("api.matchmaking.search", ["list", "delete"])

    assert not Spotter.Endpoint.Plain.has_permissions(endpoint, ["list", "update"])
  end

  test "Spotter.Endpoint.Plain.has_permission returns true for the endpoint without permissions" do
    endpoint = Spotter.Endpoint.Plain.new("api.matchmaking.search", [])

    assert Spotter.Endpoint.Plain.has_permissions(endpoint, ["get", "patch", "head"])
  end
end
