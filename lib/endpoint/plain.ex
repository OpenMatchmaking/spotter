defmodule Spotter.Endpoint.Plain do
  @moduledoc """
  Wrapper for a resource with the static path.
  """
  use Spotter.Endpoint.Base

  @doc """
  Defines the plain endpoint with static path.

  * :path - Path to the recource. For example, `api.matchmaking.search`. Required.
  * :permissions - List of permissions, required for getting an access to the resource. Default is `[]`.
  """
  @enforce_keys [:path]
  defstruct [:path, permissions: []]

  @doc """
  Checking a match of the passed path with the endpoint path by exact string comparison.
  """
  def match(endpoint, path) do
    endpoint.path == path
  end
end
