defmodule AshJsonApiWrapper.JsonApi.Cache do
  @moduledoc """
  Per-resource query result caching backed by Cachex.

  ## Setup

  Add a cache child spec for each resource with caching enabled to your supervision tree:

      children = [
        AshJsonApiWrapper.JsonApi.Cache.child_spec(MyApp.User),
        ...
      ]

  ## DSL

  Enable caching in your resource:

      json_api do
        cache_ttl :timer.minutes(5)
      end

  ## Behaviour

  - Read queries are cached by a key derived from `{resource, action, filter_params, sort_params, limit}`
  - Any successful create, update, or destroy flushes all cached entries for the resource
  - Resources without `cache_ttl` make no Cachex calls
  """

  @doc """
  Returns the Cachex cache name for a given resource module.
  """
  def cache_name(resource), do: :"#{resource}_json_api_cache"

  @doc """
  Returns a Cachex child spec suitable for adding to a supervision tree.

      children = [AshJsonApiWrapper.JsonApi.Cache.child_spec(MyApp.User)]
  """
  def child_spec(resource) do
    Cachex.child_spec(cache_name(resource))
  end

  @doc """
  Fetches a cached value. Returns `{:ok, value}` on hit, `{:ok, nil}` on miss.
  """
  def get(resource, key) do
    Cachex.get(cache_name(resource), key)
  end

  @doc """
  Stores a value in the cache with the given TTL (milliseconds).
  """
  def put(resource, key, value, ttl_ms) do
    Cachex.put(cache_name(resource), key, value, ttl: ttl_ms)
  end

  @doc """
  Flushes all cached entries for a resource. Called after successful writes.
  """
  def flush(resource) do
    Cachex.clear(cache_name(resource))
  end

  @doc """
  Derives a stable cache key from the query's action, filter params, sort params, and limit.
  """
  def derive_key(resource, action_name, filter_params, sort_params, limit) do
    :erlang.phash2({resource, action_name, filter_params, sort_params, limit})
  end
end
