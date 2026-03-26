defmodule AshJsonApiWrapper.JsonApi.FilterMapper do
  @moduledoc """
  Translates Ash filter expressions into API query parameters.

  - Equality filters on non-runtime fields → query params (`?field=value`)
  - Fields marked `runtime_filter: true` → applied in memory after fetch
  """

  @doc """
  Extracts server-side query params from an Ash query filter.
  Returns `{query_params, runtime_filters}` where:
  - `query_params` is a map of field_name → value to send as URL params
  - `runtime_filters` is a list of `{attr_name, value}` to filter in memory
  """
  def extract(query, field_mappings) do
    runtime_fields = runtime_field_names(field_mappings)
    expressions = flatten_filter(query.filter)

    {server_params, runtime_pairs} =
      Enum.reduce(expressions, {%{}, []}, fn {attr_name, value}, {params, runtime} ->
        if attr_name in runtime_fields do
          {params, [{attr_name, value} | runtime]}
        else
          {Map.put(params, to_string(attr_name), value), runtime}
        end
      end)

    {server_params, runtime_pairs}
  end

  @doc """
  Applies runtime filters to a list of records in memory.
  """
  def apply_runtime_filters(records, []), do: records

  def apply_runtime_filters(records, runtime_filters) do
    Enum.filter(records, fn record ->
      Enum.all?(runtime_filters, fn {attr_name, value} ->
        Map.get(record, attr_name) == value
      end)
    end)
  end

  # --- private ---

  defp runtime_field_names(field_mappings) do
    field_mappings
    |> Enum.filter(& &1.runtime_filter)
    |> Enum.map(& &1.name)
  end

  defp flatten_filter(nil), do: []
  defp flatten_filter(%Ash.Filter{expression: nil}), do: []

  defp flatten_filter(%Ash.Filter{expression: expression}) do
    extract_pairs(expression)
  end

  defp extract_pairs(%Ash.Query.BooleanExpression{op: :and, left: left, right: right}) do
    extract_pairs(left) ++ extract_pairs(right)
  end

  defp extract_pairs(%Ash.Query.Operator.Eq{
         left: %Ash.Query.Ref{attribute: %{name: attr_name}},
         right: %Ash.Query.Function.Type{arguments: [value | _]}
       }) do
    [{attr_name, value}]
  end

  defp extract_pairs(%Ash.Query.Operator.Eq{
         left: %Ash.Query.Ref{attribute: %{name: attr_name}},
         right: value
       })
       when not is_struct(value) do
    [{attr_name, value}]
  end

  defp extract_pairs(_), do: []
end
