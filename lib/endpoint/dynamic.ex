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

  * :regex - Regex expression for further checks with the passed path. Required.
  * :data.path - Path to the recource. For example, `api.learderboard.get.{id}`. Required.
  * :data.permissions - List of permissions, required for getting an access to the resource. Default is `[]`.
  """
  @enforce_keys [:regex, :base]
  defstruct [:regex, base: %Spotter.Endpoint.Base{}]

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Spotter.Endpoint.Dynamic

      @doc """
      Post-processing data before passing it further.
      """
      @spec transform(endpoint::UserDefined, data::any) :: {:ok, any} | {:error, String.t}
      def transform(endpoint, data), do: {:ok, data}

      @doc"""
      Validate an input data.
      """
      @spec validate(endpoint::UserDefined, data::any) :: {:ok, any} | {:error, String.t}
      def validate(endpoint, data), do: {:ok, data}

      defoverridable [transform: 2, validate: 2]
    end
  end

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
      regex: generate_regex(path),
      base: %Spotter.Endpoint.Base{
        path: path,
        permissions: permissions
      }
    }
  end

  @doc """
  Checking a match of the passed path with the endpoint path via regex search.
  """
  @spec match(endpoint::Spotter.Endpoint.Dynamic, path::String.t) :: boolean()
  def match(endpoint, path) do
    Regex.match?(endpoint.regex, path)
  end

  @doc """
  Checks that the passed permissions can provide an access to the certain resource.
  """
  @spec has_permissions(endpoint::Spotter.Endpoint.Dynamic, permissions::[String.t]) :: boolean()
  def has_permissions(endpoint, permissions) do
    access_granted?(endpoint.base.permissions, permissions)
  end
end
