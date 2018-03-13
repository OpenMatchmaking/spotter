defmodule SpotterTest do
  use ExUnit.Case

  defmodule CustomWorker do
    use Spotter.Worker

    @router Spotter.Router.new([
      {"api.matchmaking.search", ["get", "post"]},
      {"api.leaderboard.{count}", ["get", ]},
    ])

    def configure(connection, config) do
      {:ok, :good}
    end
  end

  test "Spotter.Worker contructor with empty endpoint list" do
    router = Spotter.Router.new([])

    assert router.endpoints == []
  end
end
