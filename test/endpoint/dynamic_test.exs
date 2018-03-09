defmodule SpotterEndpointDynamicTest do
  use ExUnit.Case

  test "Spotter.Endpoint.Dynamic contructor set permissions to empty list" do
    {:ok, regex_compiled} = Regex.compile("^api.leaderboard.get.(?P<var>[^{}.]+)$")
    endpoint = %Spotter.Endpoint.Dynamic{
      path: "api.leaderboard.get.{user_id}",
      regex: regex_compiled
    }

    assert endpoint.path == "api.leaderboard.get.{user_id}"
    assert endpoint.regex == ~r/^api.leaderboard.get.(?P<var>[^{}.]+)$/
    assert endpoint.permissions == []
  end

  test "Spotter.Endpoint.Dynamic contructor with custom permissions" do
    {:ok, regex_compiled} = Regex.compile("^api.leaderboard.get.(?P<var>[^{}.]+)$")
    endpoint = %Spotter.Endpoint.Dynamic{
      path: "api.leaderboard.get.{user_id}",
      regex: regex_compiled,
      permissions: ["api.leaderboard.get", ]
    }

    assert endpoint.path == "api.leaderboard.get.{user_id}"
    assert endpoint.regex == ~r/^api.leaderboard.get.(?P<var>[^{}.]+)$/
    assert endpoint.permissions == ["api.leaderboard.get", ]
  end

  test "Spotter.Endpoint.Dynamic.match returns true for exact match" do
    {:ok, regex_compiled} = Regex.compile("^api.leaderboard.get.(?P<var>[^{}.]+)$")
    endpoint = %Spotter.Endpoint.Dynamic{
      path: "api.leaderboard.get.{user_id}",
      regex: regex_compiled,
      permissions: ["api.leaderboard.get", ]
    }

    assert Spotter.Endpoint.Dynamic.match(endpoint, "api.leaderboard.get.user-123456789")
  end

  test "Spotter.Endpoint.Dynamic.match returns false for not matched path" do
    {:ok, regex_compiled} = Regex.compile("^api.leaderboard.get.(?P<var>[^{}.]+)$")
    endpoint = %Spotter.Endpoint.Dynamic{
      path: "api.leaderboard.get.{user_id}",
      regex: regex_compiled,
      permissions: ["api.leaderboard.get", ]
    }

    assert not Spotter.Endpoint.Plain.match(endpoint, "some.another.api")
  end

  test "Spotter.Endpoint.Dynamic.has_permission returns true for correct permissions" do
    {:ok, regex_compiled} = Regex.compile("^api.leaderboard.get.(?P<var>[^{}.]+)$")
    endpoint = %Spotter.Endpoint.Dynamic{
      path: "api.leaderboard.get.{user_id}",
      regex: regex_compiled,
      permissions: ["get", "update"]
    }

    assert Spotter.Endpoint.Plain.has_permission(endpoint, ["get", "update", "delete"])
  end

  test "Spotter.Endpoint.Dynamic.has_permission returns false for invalid permissions" do
    {:ok, regex_compiled} = Regex.compile("^api.leaderboard.get.(?P<var>[^{}.]+)$")
    endpoint = %Spotter.Endpoint.Dynamic{
      path: "api.leaderboard.get.{user_id}",
      regex: regex_compiled,
      permissions: ["list", "delete"]
    }

    assert not Spotter.Endpoint.Plain.has_permission(endpoint, ["list", "update"])
  end

  test "Spotter.Endpoint.Dynamic.has_permission returns true for the endpoint without permissions" do
    {:ok, regex_compiled} = Regex.compile("^api.leaderboard.get.(?P<var>[^{}.]+)$")
    endpoint = %Spotter.Endpoint.Dynamic{
      path: "api.leaderboard.get.{user_id}",
      regex: regex_compiled
    }

    assert Spotter.Endpoint.Plain.has_permission(endpoint, ["get", "patch", "head"])
  end
end
