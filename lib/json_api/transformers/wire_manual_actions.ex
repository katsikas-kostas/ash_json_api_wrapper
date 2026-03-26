defmodule AshJsonApiWrapper.JsonApi.Transformers.WireManualActions do
  @moduledoc """
  Spark transformer that wires ManualRead into read actions for json_api resources.
  """
  use Spark.Dsl.Transformer

  @impl true
  def after?(_), do: true

  @impl true
  def transform(dsl_state) do
    base_url = Spark.Dsl.Extension.get_opt(dsl_state, [:json_api], :base_url)
    resource_path = Spark.Dsl.Extension.get_opt(dsl_state, [:json_api], :resource_path)
    opts = [base_url: base_url, resource_path: resource_path]

    read_actions =
      dsl_state
      |> Spark.Dsl.Transformer.get_entities([:actions])
      |> Enum.filter(&(&1.type == :read))

    if Enum.empty?(read_actions) do
      {:error,
       Spark.Error.DslError.exception(
         module: Spark.Dsl.Transformer.get_persisted(dsl_state, :module),
         path: [:json_api],
         message:
           "AshJsonApiWrapper.JsonApi requires at least one read action. Add `defaults [:read]` to your actions block."
       )}
    else
      dsl_state =
        Enum.reduce(read_actions, dsl_state, fn action, dsl ->
          updated = %{action | manual: {AshJsonApiWrapper.JsonApi.ManualRead, opts}}

          Spark.Dsl.Transformer.replace_entity(dsl, [:actions], updated, fn existing ->
            existing.name == action.name && existing.type == :read
          end)
        end)

      {:ok, dsl_state}
    end
  end
end
