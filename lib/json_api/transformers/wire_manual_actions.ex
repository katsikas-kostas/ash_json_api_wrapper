defmodule AshJsonApiWrapper.JsonApi.Transformers.WireManualActions do
  @moduledoc """
  Spark transformer that wires manual action modules into actions for json_api resources.
  """
  use Spark.Dsl.Transformer

  @impl true
  def after?(_), do: true

  @impl true
  def transform(dsl_state) do
    base_url = Spark.Dsl.Extension.get_opt(dsl_state, [:json_api], :base_url)
    resource_path = Spark.Dsl.Extension.get_opt(dsl_state, [:json_api], :resource_path)
    opts = [base_url: base_url, resource_path: resource_path]

    actions = Spark.Dsl.Transformer.get_entities(dsl_state, [:actions])
    read_actions = Enum.filter(actions, &(&1.type == :read))

    if Enum.empty?(read_actions) do
      {:error,
       Spark.Error.DslError.exception(
         module: Spark.Dsl.Transformer.get_persisted(dsl_state, :module),
         path: [:json_api],
         message:
           "AshJsonApiWrapper.JsonApi requires at least one read action. Add `defaults [:read]` to your actions block."
       )}
    else
      dsl_state = wire_actions(dsl_state, read_actions, AshJsonApiWrapper.JsonApi.ManualRead, opts)
      create_actions = Enum.filter(actions, &(&1.type == :create))
      dsl_state = wire_actions(dsl_state, create_actions, AshJsonApiWrapper.JsonApi.ManualCreate, opts)

      update_actions = Enum.filter(actions, &(&1.type == :update))
      dsl_state = wire_actions(dsl_state, update_actions, AshJsonApiWrapper.JsonApi.ManualUpdate, opts)

      destroy_actions = Enum.filter(actions, &(&1.type == :destroy))
      dsl_state = wire_actions(dsl_state, destroy_actions, AshJsonApiWrapper.JsonApi.ManualDestroy, opts)

      {:ok, dsl_state}
    end
  end

  defp wire_actions(dsl_state, actions, module, opts) do
    Enum.reduce(actions, dsl_state, fn action, dsl ->
      updated = %{action | manual: {module, opts}}

      Spark.Dsl.Transformer.replace_entity(dsl, [:actions], updated, fn existing ->
        existing.name == action.name && existing.type == action.type
      end)
    end)
  end
end
