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
    {filter_params, runtime_filters} = FilterMapper.extract(query, field_mappings)
    sort_params = SortMapper.extract(query, opts[:sort_param] || "sort")

    query_params = Map.merge(filter_params, sort_params)
    url = build_url(base_url, resource_path, query, query_params)


    case AshJsonApiWrapper.JsonApi.Client.get(url, resource) do
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

  defp build_url(base_url, resource_path, query, filter_params \\ %{}) do
    base =
      case get_id_filter(query) do
        nil -> base_url <> resource_path
        id -> base_url <> resource_path <> "/#{id}"
      end

    if map_size(filter_params) == 0 do
      base
    else
      query_string = URI.encode_query(filter_params)
      base <> "?" <> query_string
    end
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
