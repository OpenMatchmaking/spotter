defmodule Spotter.Endpoint.Base do
  @moduledoc """
  Base module for implementing endpoints.

  By default any module must implement three required functions, that's going to use this
  functionality later:
  - `new(path, permissions)` for creating a new instance of a structure
  - `match(endpoint, path)` for getting an understanding that the appropriate endpoint
  - `has_permissions(endpoint, permissions)` for checking an access to the particular resource

  Also the base module provides two methods, each of those returns an input data as is
  by default, but can be overridden:
  - `tranform(data)` for post-processing data before passing it further
  - `validate(data)` for validating an input data
  """
  defstruct [:path, permissions: []]

  @callback new(path::Strint.t, permissions::[String.t]) :: UserDefined
  @callback match(endpoint::any, path::String.t) :: boolean()
  @callback has_permissions(endpoint::any, permissions::[String.t]) :: boolean()

  @doc false
  defmacro __using__(_opts) do
    quote do
      @behaviour Spotter.Endpoint.Base

      @doc """
      Post-processing data before passing it further.
      """
      @spec transform(endpoint::any, data::any) :: {:ok, any} | {:error, String.t}
      def transform(endpoint, data), do: {:ok, data}

      @doc"""
      Validate an input data.
      """
      @spec validate(endpoint::any, data::any) :: {:ok, any} | {:error, String.t}
      def validate(endpoint, data), do: {:ok, data}

      @doc """
      Checks for all specified permissions from the first list in the second.
      """
      @spec access_granted?(required_permissions::[String.t], permissions::[String.t]) :: boolean()
      def access_granted?(required_permissions, permissions) do
        MapSet.subset?(MapSet.new(required_permissions), MapSet.new(permissions))
      end

      defoverridable [transform: 2, validate: 2, access_granted?: 2]
    end
  end
end
