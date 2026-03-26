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

    field_mappings = opts[:field_mappings] || []
    action_overrides = opts[:action_overrides] || []
    override = find_override(action_overrides, query.action.name)

    {filter_params, runtime_filters} = FilterMapper.extract(query, field_mappings)
    sort_params = SortMapper.extract(query, opts[:sort_param] || "sort")

    query_params = Map.merge(filter_params, sort_params)
    url = build_url(base_url, resource_path, query, query_params, override)

    method = override && override.method || :get
    result = dispatch(method, url, query_params, resource, opts)

    case result do
      {:ok, body} ->
        entities = ResponseMapper.extract_entities(body, opts[:entity_path])
        records = ResponseMapper.to_records(entities, resource, opts)
        {:ok, FilterMapper.apply_runtime_filters(records, runtime_filters)}

      {:error, {:http_error, 404, _body}} ->
        {:ok, []}

      {:error, {:http_error, status, body}} ->
        {:error, ErrorMapper.to_error(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch(:get, url, _query_params, resource, opts) do
    AshJsonApiWrapper.JsonApi.Client.get(url, resource, opts)
  end

  defp dispatch(:post, url, query_params, resource, opts) do
    AshJsonApiWrapper.JsonApi.Client.post(url, query_params, resource, opts)
  end

  defp build_url(base_url, resource_path, query, filter_params, override) do
    path = (override && override.path) || resource_path
    id = get_id_filter(query)

    base =
      cond do
        # path template already contains :id
        id && String.contains?(path, ":id") ->
          base_url <> String.replace(path, ":id", to_string(id))

        id ->
          base_url <> path <> "/#{id}"

        true ->
          base_url <> path
      end

    method = override && override.method || :get

    # For non-GET overrides, query params go in body; don't append to URL
    if method == :get && map_size(filter_params) > 0 do
      base <> "?" <> URI.encode_query(filter_params)
    else
      base
    end
  end

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
