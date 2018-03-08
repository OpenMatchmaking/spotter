defmodule SpotterTest do
  use ExUnit.Case

  test "Spotter.Endpoint.Plain contuctor set permissions to empty list" do
    endpoint = %Spotter.Endpoint.Plain{path: "api.matchmaking.search"}

    assert endpoint.path == "api.matchmaking.search"
    assert endpoint.permissions == []
  end

  test "Spotter.Endpoint.Plain contuctor with custom permissions" do
    endpoint = %Spotter.Endpoint.Plain{
      path: "api.matchmaking.search",
      permissions: ["api.search.retrieve", ]
    }

    assert endpoint.path == "api.matchmaking.search"
    assert endpoint.permissions == ["api.search.retrieve", ]
  end

  test "Spotter.Endpoint.Plain.match returns true for exact match" do
    endpoint = %Spotter.Endpoint.Plain{
      path: "api.matchmaking.search",
      permissions: ["api.search.retrieve", ]
    }

    assert Spotter.Endpoint.Plain.match(endpoint, "api.matchmaking.search")
  end

  test "Spotter.Endpoint.Plain.match returns false for not matched path" do
    endpoint = %Spotter.Endpoint.Plain{
      path: "api.matchmaking.search",
      permissions: ["get", ]
    }

    assert not Spotter.Endpoint.Plain.match(endpoint, "some.another.api")
  end

  test "Spotter.Endpoint.Plain.has_permission returns true for correct permissions" do
    endpoint = %Spotter.Endpoint.Plain{
      path: "api.matchmaking.search",
      permissions: ["get", "update"]
    }

    assert Spotter.Endpoint.Plain.has_permission(endpoint, ["get", "update", "delete"])
  end

  test "Spotter.Endpoint.Plain.has_permission returns false for invalid permissions" do
    endpoint = %Spotter.Endpoint.Plain{
      path: "api.matchmaking.search",
      permissions: ["list", "delete"]
    }

    assert not Spotter.Endpoint.Plain.has_permission(endpoint, ["list", "update"])
  end

  test "Spotter.Endpoint.Plain.has_permission returns true for the endpoint without permissions" do
    endpoint = %Spotter.Endpoint.Plain{path: "api.matchmaking.search"}

    assert Spotter.Endpoint.Plain.has_permission(endpoint, ["get", "patch", "head"])
  end
end
