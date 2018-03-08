defmodule Spotter.Endpoint.Base do
  @moduledoc """
  Base module for describing endpoints.

  This module provides two methods, each of those returns an input data as is by default:
  - `tranform(data)` for post-processing data before passing it further
  - `validate(data)` for validating an input data

  and two required functions for any module, that's going to use this functionality later:
  - `match(endpoint, path)` for getting an understanding that the appropriate endpoint
  - `has_permission` for checking an access to the particular resource
  """
  @callback match(endpoint::any, path::String.t) :: boolean()
  @callback has_permission(endpoint::any, client_permissions::[String.t]) :: boolean()

  @doc false
  defmacro __using__(_opts) do
    quote do
      # Any derived module should implement the callback
      @behaviour Spotter.Endpoint.Base

      @doc """
      Post-processing data before passing it further
      """
      @spec transform(any) :: {:ok, any} | {:error, String.t}
      def transform(data), do: data

      @doc"""
      Validate an input data
      """
      @spec validate(any) :: {:ok, any} | {:error, String.t}
      def validate(data), do: data

      defoverridable [transform: 1, validate: 1, ]
    end
  end
end
