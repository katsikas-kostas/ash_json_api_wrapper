defmodule AshJsonApiWrapper.JsonApi.ManualCreate do
  @moduledoc """
  Implements `Ash.Resource.ManualCreate` for JSON API-backed resources.
  """
  use Ash.Resource.ManualCreate

  alias AshJsonApiWrapper.JsonApi.{ErrorMapper, ResponseMapper}

  @impl true
  def create(changeset, opts, _context) do
    base_url = opts[:base_url]
    resource_path = opts[:resource_path]
    resource = changeset.resource

    url = base_url <> resource_path
    attrs = changeset.attributes

    case AshJsonApiWrapper.JsonApi.Client.post(url, attrs, resource) do
      {:ok, body} ->
        entity = ResponseMapper.extract_entities(body, opts[:entity_path])
        entity = if is_list(entity), do: List.first(entity), else: entity
        {:ok, ResponseMapper.to_record(entity, resource, opts)}

      {:error, {:http_error, status, body}} ->
        {:error, ErrorMapper.to_error(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
