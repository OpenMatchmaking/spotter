defmodule Spotter.Endpoint.Plain do
  @moduledoc """
  Wrapper for a resource with the static path.
  """
  use Spotter.Endpoint.Base

  @doc """
  Defines the plain endpoint with static path.

  * :data.path - Path to the resource. For example, `api.matchmaking.search`. Required.
  * :data.permissions - List of permissions, required for getting an access to the resource. Default is `[]`.
  """
  @enforce_keys [:base]
  defstruct base: %Spotter.Endpoint.Base{}

  @doc """
  Returns a new instance of Spotter.Endpoint.Plain struct.
  """
  @spec new(path::String.t, permissions::[String.t]) :: Spotter.Endpoint.Plain
  def new(path, permissions) do
    %Spotter.Endpoint.Plain{
      base: %Spotter.Endpoint.Base{
        path: path,
        permissions: permissions
      }
    }
  end

  @doc """
  Checking a match of the passed path with the endpoint path by exact string comparison.
  """
  @spec match(endpoint::Spotter.Endpoint.Plain, path::String.t) :: boolean()
  def match(endpoint, path) do
    endpoint.base.path == path
  end

  @doc """
  Checks that the passed permissions can provide an access to the certain resource.
  """
  @spec has_permissions(endpoint::Spotter.Endpoint.Plain, permissions::[String.t]) :: boolean()
  def has_permissions(endpoint, permissions) do
    access_granted?(endpoint.base.permissions, permissions)
  end
end
