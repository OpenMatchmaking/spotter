defmodule Spotter.Router do
  @moduledoc """
  Router struct that handles the endpoints and makes dispatching.
  """
  @typep default_endpoint_struct :: Spotter.Endpoint.Plain | Spotter.Endpoint.Dynamic
  @typep default_endpoint_args :: {String.t, [String.t]}
  @typep custom_endpoint_args :: {String.t, [String.t], UserDefined}
  @typep dispatch_result :: default_endpoint_struct | UserDefined | nil

  @doc """
  Defines the router struct.

  * :endpoints - List of endpoints, where each endpoint represented as the
  `Spotter.Endpoint.Plain` or the `Spotter.Endpoint.Dynamic` or a Used Defined structure,
  derived from the `Spotter.Endpoint.Base`.
  """
  @enforce_keys [:endpoints]
  defstruct [:endpoints]

  # Converts a passed tuple to the custom endpoints structure
  @spec convert_to_endpoint(custom_endpoint_args) :: UserDefined
  defp convert_to_endpoint({path, permissions, custom_structure}) do
    custom_structure.new(path, permissions)
  end

  # Converts a passed tuple to the default endpoint structure
  @spec convert_to_endpoint(default_endpoint_args) :: default_endpoint_struct
  defp convert_to_endpoint({path, permissions}) do
    case String.contains?(path, ["{", "}"]) do
      true -> Spotter.Endpoint.Dynamic.new(path, permissions)
      false -> Spotter.Endpoint.Plain.new(path, permissions)
    end
  end

  @doc """
  Creates a new router based on the list of tuples. Each tuples represent an
  endpoints, that required for pre-processing and validating.
  """
  @spec new(endpoints::[default_endpoint_args | custom_endpoint_args]) :: Spotter.Router
  def new(endpoints) do
    %Spotter.Router{endpoints: Enum.map(endpoints, &(convert_to_endpoint(&1)))}
  end

  @doc """
  Returns an endpoint that matches to the `path` argument. Otherwise returns `nil`.
  """
  @spec dispatch(router::Spotter.Router, path::Strint.t) :: dispatch_result
  def dispatch(router, path) do
    Enum.find(router.endpoints, fn(endpoint) -> endpoint.__struct__.match(endpoint, path) end)
  end
end
