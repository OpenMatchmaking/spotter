defmodule Spotter.Endpoint.Dynamic do
  @moduledoc """
  Wrapper for a resource with the dynamic path.
  """
  use Spotter.Endpoint.Base

  @good_match "[^{}\/.]+"
  @dynamic_parameter ~r/({\s*[\w\d_-]+\s*})/
  @valid_dynamic_parameter ~r/{(?P<var>[\w][\w\d_-]*)}/

  @doc """
  Defines the endpoint with dynamic path.

  * :path - Path to the recource. For example, `api.learderboard.get.{id}`. Required.
  * :regex - Regex expression for further checks with the passed path. Required.
  * :permissions - List of permissions, required for getting an access to the resource. Default is `[]`.
  """
  @enforce_keys [:path, :regex]
  defstruct [:path, :regex, permissions: []]

  # Generates a regular expression for the dynamic parameter in URL if it was found. Otherwise
  # will return a string as is.
  @spec process_path_part(path::String.t) :: String.t
  defp process_path_part(path) do
    case Regex.match?(@valid_dynamic_parameter, path) do
      true -> Enum.join(['(?P<', Regex.named_captures(@valid_dynamic_parameter, path)["var"], '>', @good_match, ")"], "")
      false -> path
    end
  end

  @doc """
  Generates a regular expression based on the passed `path` string argument. Can raise the
  Regex.CompileError in case of errors.
  """
  @spec generate_regex(path::String.t) :: String.t
  def generate_regex(path) do
    parsed_path = Regex.split(@dynamic_parameter, path, include_captures: true)
      |> Enum.map(&(process_path_part(&1)))
      |> Enum.join("")
    regex = Enum.join(['^', parsed_path, '$'], "")
    Regex.compile!(regex)
  end

  @doc """
  Returns a new instance of Spotter.Endpoint.Dynamic struct.
  """
  @spec new(path::String.t, permissions::[String.t]) :: Spotter.Endpoint.Dynamic
  def new(path, permissions) do
    %Spotter.Endpoint.Dynamic{
      path: path,
      regex: generate_regex(path),
      permissions: permissions
    }
  end

  @doc """
  Checking a match of the passed path with the endpoint path via regex search.
  """
  def match(endpoint, path) do
    Regex.match?(endpoint.regex, path)
  end
end
