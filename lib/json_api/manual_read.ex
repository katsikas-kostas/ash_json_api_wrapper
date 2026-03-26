defmodule AshJsonApiWrapper.JsonApi.ManualRead do
  @moduledoc """
  Implements `Ash.Resource.ManualRead` for JSON API-backed resources.
  """
  use Ash.Resource.ManualRead

  alias AshJsonApiWrapper.JsonApi.RecordMapper

  @impl true
  def read(query, _data_layer_query, opts, _context) do
    base_url = opts[:base_url]
    resource_path = opts[:resource_path]
    resource = query.resource

    url = build_url(base_url, resource_path, query)

    case AshJsonApiWrapper.JsonApi.Client.get(url, resource) do
      {:ok, body} ->
        {:ok, RecordMapper.to_records(body, resource)}

      {:error, {:http_error, 404, _body}} ->
        {:ok, []}

      {:error, {:http_error, status, body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

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
