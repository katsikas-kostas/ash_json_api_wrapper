defmodule AshJsonApiWrapper.ManualRead do
  @moduledoc """
  Implements `Ash.Resource.ManualRead` for JSON API-backed resources.
  """
  use Ash.Resource.ManualRead

  @impl true
  def read(query, _data_layer_query, opts, _context) do
    base_url = opts[:base_url]
    resource_path = opts[:resource_path]
    resource = query.resource

    url = build_url(base_url, resource_path, query)

    case AshJsonApiWrapper.Client.get(url, resource) do
      {:ok, body} ->
        records = to_records(body, resource)
        {:ok, records}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_url(base_url, resource_path, query) do
    case get_id_filter(query) do
      nil -> base_url <> resource_path
      id -> base_url <> resource_path <> "/#{id}"
    end
  end

  defp get_id_filter(%{filter: %Ash.Filter{expression: expression}}) do
    extract_id(expression)
  end

  defp get_id_filter(_), do: nil

  defp extract_id(%Ash.Query.Operator.Eq{
         left: %Ash.Query.Ref{attribute: %{name: :id}},
         right: %Ash.Query.Function.Type{arguments: [%Ash.Query.Ref{attribute: %{name: :id}} | _]}
       }) do
    # This is the Ash.get pattern where the filter is: id == type(^id_value, ...)
    nil
  end

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

  defp to_records(body, resource) when is_list(body) do
    Enum.map(body, &to_record(&1, resource))
  end

  defp to_records(body, resource) when is_map(body) do
    [to_record(body, resource)]
  end

  defp to_record(item, resource) do
    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.reduce(%{}, fn attr, acc ->
      case Map.get(item, to_string(attr.name)) do
        nil -> acc
        value -> Map.put(acc, attr.name, value)
      end
    end)
    |> then(&struct(resource, &1))
  end
end
