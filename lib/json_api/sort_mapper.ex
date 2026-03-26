defmodule AshJsonApiWrapper.JsonApi.SortMapper do
  @moduledoc """
  Translates Ash sort expressions into API query parameters.

  `Ash.Query.sort(:name)` → `?sort=name`
  `Ash.Query.sort(name: :desc)` → `?sort=-name`
  Multi-field: `?sort=name,-created_at`
  """

  @doc """
  Returns a query param map for the sort expression, or empty map if no sort.
  """
  def extract(%{sort: nil}, _sort_param), do: %{}
  def extract(%{sort: []}, _sort_param), do: %{}

  def extract(%{sort: sort}, sort_param) do
    sort_value =
      sort
      |> Enum.map_join(",", fn
        {field, :asc} -> to_string(field)
        {field, :desc} -> "-#{field}"
        field when is_atom(field) -> to_string(field)
      end)

    %{sort_param => sort_value}
  end
end
