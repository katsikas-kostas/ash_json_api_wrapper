defmodule AshJsonApiWrapper.JsonApi.RecordMapper do
  @moduledoc false

  def to_records(body, resource) when is_list(body) do
    Enum.map(body, &to_record(&1, resource))
  end

  def to_records(body, resource) when is_map(body) do
    [to_record(body, resource)]
  end

  def to_record(item, resource) do
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
