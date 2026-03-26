defmodule AshJsonApiWrapper.JsonApi.ResponseMapper do
  @moduledoc """
  Transforms API response bodies into Ash records.

  Supports:
  - `entity_path` — extract entities from nested response (e.g., `"data.items"`)
  - field `path` mappings — map nested JSON fields to Ash attributes
  - `case_convention: :camel_case` — auto-convert camelCase keys to snake_case
  """

  @doc """
  Extracts a list of raw maps from the response body using the configured entity_path.
  """
  def extract_entities(body, nil), do: body

  def extract_entities(body, entity_path) when is_binary(entity_path) do
    keys = String.split(entity_path, ".")

    Enum.reduce(keys, body, fn key, acc ->
      case acc do
        map when is_map(map) -> Map.get(map, key)
        _ -> acc
      end
    end)
  end

  @doc """
  Converts a raw API map into an Ash resource struct, applying field mappings and
  case convention transformation.
  """
  def to_record(item, resource, opts) do
    field_mappings = opts[:field_mappings] || []
    case_convention = opts[:case_convention]

    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.reduce(%{}, fn attr, acc ->
      value = resolve_value(item, attr.name, field_mappings, case_convention)

      case value do
        :not_found -> acc
        value -> Map.put(acc, attr.name, value)
      end
    end)
    |> then(&struct(resource, &1))
  end

  def to_records(body, resource, opts) when is_list(body) do
    Enum.map(body, &to_record(&1, resource, opts))
  end

  def to_records(body, resource, opts) when is_map(body) do
    [to_record(body, resource, opts)]
  end

  # --- private ---

  defp resolve_value(item, attr_name, field_mappings, case_convention) do
    case find_field_mapping(field_mappings, attr_name) do
      %{path: path} when is_binary(path) ->
        fetch_nested(item, String.split(path, "."))

      _ ->
        key = attribute_key(attr_name, case_convention)
        fetch_key(item, key)
    end
  end

  defp find_field_mapping(field_mappings, attr_name) do
    Enum.find(field_mappings, &(&1.name == attr_name))
  end

  defp attribute_key(attr_name, :camel_case), do: snake_to_camel(to_string(attr_name))
  defp attribute_key(attr_name, _), do: to_string(attr_name)

  defp snake_to_camel(snake) do
    [first | rest] = String.split(snake, "_")
    first <> Enum.map_join(rest, "", &String.capitalize/1)
  end

  defp fetch_nested(item, [key]) do
    fetch_key(item, key)
  end

  defp fetch_nested(item, [key | rest]) when is_map(item) do
    case Map.fetch(item, key) do
      {:ok, nested} -> fetch_nested(nested, rest)
      :error -> :not_found
    end
  end

  defp fetch_nested(_, _), do: :not_found

  defp fetch_key(item, key) when is_map(item) do
    case Map.fetch(item, key) do
      {:ok, value} -> value
      :error -> :not_found
    end
  end

  defp fetch_key(_, _), do: :not_found
end
