defmodule Spotter.Endpoint.Dynamic do
  @moduledoc """
  Wrapper for a resource with the dynamic path.
  """
  use Spotter.Endpoint.Base

  @doc """
  Defines the endpoint with dynamic path.

  * :path - Path to the recource. For example, `api/learderboard/get/{id}`. Required.
  * :regex - Regex expression for further checks with the passed path. Required.
  * :permissions - List of permissions, required for getting an access to the resource. Default is `[]`.
  """
  @enforce_keys [:path, :regex]
  defstruct [:path, :regex, permissions: []]

  @doc """
  Checking a match of the passed path with the endpoint path via regex search.
  """
  def match(endpoint, path) do
    Regex.match?(endpoint.regex, path)
  end
end
