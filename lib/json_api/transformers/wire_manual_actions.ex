defmodule AshJsonApiWrapper.JsonApi.Transformers.WireManualActions do
  @moduledoc """
  Spark transformer that wires ManualRead into read actions for json_api resources.
  """
  use Spark.Dsl.Transformer

  def after?(_), do: true

  def transform(dsl_state) do
    base_url = Spark.Dsl.Extension.get_opt(dsl_state, [:json_api], :base_url)
    resource_path = Spark.Dsl.Extension.get_opt(dsl_state, [:json_api], :resource_path)
    opts = [base_url: base_url, resource_path: resource_path]

    dsl_state =
      dsl_state
      |> Spark.Dsl.Transformer.get_entities([:actions])
      |> Enum.filter(&(&1.type == :read))
      |> Enum.reduce(dsl_state, fn action, dsl ->
        updated = %{action | manual: {AshJsonApiWrapper.ManualRead, opts}}

        Spark.Dsl.Transformer.replace_entity(dsl, [:actions], updated, fn existing ->
          existing.name == action.name && existing.type == :read
        end)
      end)

    {:ok, dsl_state}
  end
end
