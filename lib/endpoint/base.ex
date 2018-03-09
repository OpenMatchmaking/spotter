defmodule Spotter.Endpoint.Base do
  @moduledoc """
  Base module for describing endpoints.

  This module provides three methods, each of those returns an input data as is by default:
  - `tranform(data)` for post-processing data before passing it further
  - `validate(data)` for validating an input data
  - `has_permission(endpoint, path)` for checking an access to the particular resource

  and one required function for any module, that's going to use this functionality later:
  - `match(endpoint, path)` for getting an understanding that the appropriate endpoint
  """
  @callback match(endpoint::any, path::String.t) :: boolean()

  @doc false
  defmacro __using__(_opts) do
    quote do
      # Any derived module should implement the callback
      @behaviour Spotter.Endpoint.Base

      @doc """
      Post-processing data before passing it further.
      """
      @spec transform(any) :: {:ok, any} | {:error, String.t}
      def transform(data), do: data

      @doc"""
      Validate an input data.
      """
      @spec validate(any) :: {:ok, any} | {:error, String.t}
      def validate(data), do: data

      @doc """
      Checks that the passed permissions can provide an access to the certain resource.
      """
      @spec has_permission(any, [String.t]) :: boolean()
      def has_permission(endpoint, permissions) do
        case endpoint.permissions do
          [] -> true
          required_permissions -> MapSet.subset?(
                                    MapSet.new(required_permissions),
                                    MapSet.new(permissions)
                                  )
        end
      end

      defoverridable [transform: 1, validate: 1, has_permission: 2]
    end
  end
end
