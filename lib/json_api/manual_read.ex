defmodule AshJsonApiWrapper.JsonApi.ManualRead do
  @moduledoc """
  Implements `Ash.Resource.ManualRead` for JSON API-backed resources.
  """
  use Ash.Resource.ManualRead

  alias AshJsonApiWrapper.JsonApi.{ErrorMapper, FilterMapper, ResponseMapper, SortMapper}

  @impl true
  def read(query, _data_layer_query, opts, _context) do
    base_url = opts[:base_url]
    resource_path = opts[:resource_path]
    resource = query.resource
    cache_ttl = opts[:cache_ttl]

    field_mappings = opts[:field_mappings] || []
    action_overrides = opts[:action_overrides] || []
    override = find_override(action_overrides, query.action.name)

    {filter_params, runtime_filters} = FilterMapper.extract(query, field_mappings)
    sort_params = SortMapper.extract(query, opts[:sort_param] || "sort")
    base_query_params = Map.merge(filter_params, sort_params)

    base_url_with_path = build_base_url(base_url, resource_path, query, override)
    method = (override && override.method) || :get
    limit = query.limit

    if cache_ttl do
      cache_key = AshJsonApiWrapper.JsonApi.Cache.derive_key(
        resource, query.action.name, filter_params, sort_params, limit
      )

      case AshJsonApiWrapper.JsonApi.Cache.get(resource, cache_key) do
        {:ok, nil} ->
          result = do_read(base_url_with_path, base_query_params, resource, method, opts, limit)
          case result do
            {:ok, records} ->
              AshJsonApiWrapper.JsonApi.Cache.put(resource, cache_key, records, cache_ttl)
              finish(records, resource, opts, runtime_filters, limit)
            error -> handle_error(error)
          end

        {:ok, records} ->
          finish(records, resource, opts, runtime_filters, limit)

        _ ->
          result = do_read(base_url_with_path, base_query_params, resource, method, opts, limit)
          handle_read_result(result, resource, opts, runtime_filters, limit)
      end
    else
      result = do_read(base_url_with_path, base_query_params, resource, method, opts, limit)
      handle_read_result(result, resource, opts, runtime_filters, limit)
    end
  end

  defp do_read(base_url_with_path, base_query_params, resource, method, opts, limit) do
    case opts[:paginator] do
      nil ->
        url = append_query_params(base_url_with_path, base_query_params, method)
        fetch_single(url, base_query_params, resource, method, opts)

      paginator_ref ->
        fetch_paginated(base_url_with_path, base_query_params, resource, method, opts, paginator_ref, limit)
    end
  end

  defp handle_read_result(result, resource, opts, runtime_filters, limit) do
    case result do
      {:ok, records} -> finish(records, resource, opts, runtime_filters, limit)
      error -> handle_error(error)
    end
  end

  defp finish(raw_entities, resource, opts, runtime_filters, limit) do
    mapped = ResponseMapper.to_records(raw_entities, resource, opts)
    filtered = FilterMapper.apply_runtime_filters(mapped, runtime_filters)
    limited = if limit, do: Enum.take(filtered, limit), else: filtered
    {:ok, limited}
  end

  defp handle_error({:error, {:http_error, 404, _body}}), do: {:ok, []}
  defp handle_error({:error, {:http_error, status, body}}), do: {:error, ErrorMapper.to_error(status, body)}
  defp handle_error({:error, reason}), do: {:error, reason}

  # --- Single page fetch ---

  defp fetch_single(url, query_params, resource, :get, opts) do
    case AshJsonApiWrapper.JsonApi.Client.get(url, resource, opts) do
      {:ok, body} -> {:ok, ResponseMapper.extract_entities(body, opts[:entity_path])}
      error -> error
    end
  end

  defp fetch_single(url, query_params, resource, :post, opts) do
    case AshJsonApiWrapper.JsonApi.Client.post(url, query_params, resource, opts) do
      {:ok, body} -> {:ok, ResponseMapper.extract_entities(body, opts[:entity_path])}
      error -> error
    end
  end

  # --- Paginated fetch ---

  defp fetch_paginated(base_url, base_query_params, resource, method, opts, paginator_ref, limit) do
    {mod, pag_opts} = normalize_paginator(paginator_ref)

    case mod.start(pag_opts) do
      {:ok, state} ->
        do_fetch_pages(base_url, base_query_params, resource, method, opts, mod, pag_opts, state, [], limit)

      error ->
        error
    end
  end

  defp do_fetch_pages(base_url, base_query_params, resource, method, opts, mod, pag_opts, state, acc, limit) do
    page_params = Map.merge(base_query_params, Map.get(state, :params, %{}))
    url = append_query_params(base_url, page_params, method)

    result =
      case method do
        :get -> AshJsonApiWrapper.JsonApi.Client.get(url, resource, opts)
        :post -> AshJsonApiWrapper.JsonApi.Client.post(url, page_params, resource, opts)
      end

    case result do
      {:ok, body} ->
        entities = ResponseMapper.extract_entities(body, opts[:entity_path])
        page_records = ensure_list(entities)
        all_records = acc ++ page_records

        # Stop if Ash limit is satisfied
        if limit && length(all_records) >= limit do
          {:ok, all_records}
        else
          pag_opts_with_state = Keyword.put(pag_opts, :accumulated_count, length(all_records))

          case mod.continue(body, page_records, pag_opts_with_state) do
            :halt ->
              {:ok, all_records}

            {:ok, next_state} ->
              do_fetch_pages(base_url, base_query_params, resource, method, opts, mod, pag_opts, next_state, all_records, limit)
          end
        end

      error ->
        error
    end
  end

  # --- URL helpers ---

  defp build_base_url(base_url, resource_path, query, override) do
    path = (override && override.path) || resource_path
    id = get_id_filter(query)

    cond do
      id && String.contains?(path, ":id") ->
        base_url <> String.replace(path, ":id", to_string(id))

      id ->
        base_url <> path <> "/#{id}"

      true ->
        base_url <> path
    end
  end

  defp append_query_params(url, params, :get) when map_size(params) > 0 do
    url <> "?" <> URI.encode_query(params)
  end

  defp append_query_params(url, _params, _method), do: url

  defp normalize_paginator({mod, opts}) when is_atom(mod), do: {mod, opts}
  defp normalize_paginator(mod) when is_atom(mod), do: {mod, []}

  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(item) when is_map(item), do: [item]
  defp ensure_list(_), do: []

  defp find_override(overrides, action_name) do
    Enum.find(overrides, &(&1.name == action_name))
  end

  defp get_id_filter(%{filter: %Ash.Filter{expression: expression}}) do
    extract_id(expression)
  end

  defp get_id_filter(_), do: nil

  defp extract_id(%Ash.Query.Operator.Eq{
         left: %Ash.Query.Ref{attribute: %{name: :id}},
         right: %Ash.Query.Function.Type{arguments: [value | _]}
       }) do
    value
  end

  defp extract_id(%Ash.Query.Operator.Eq{
         left: %Ash.Query.Ref{attribute: %{name: :id}},
         right: value
       })
       when is_binary(value) do
    value
  end

  defp extract_id(_), do: nil
end
