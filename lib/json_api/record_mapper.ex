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
      case Map.fetch(item, to_string(attr.name)) do
        {:ok, value} -> Map.put(acc, attr.name, value)
        :error -> acc
      end
    end)
    |> then(&struct(resource, &1))
  end
end
