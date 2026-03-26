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

    case AshJsonApiWrapper.JsonApi.Client.post(url, attrs, resource, opts) do
      {:ok, body} ->
        entity = ResponseMapper.extract_entity(body, opts[:entity_path])
        {:ok, ResponseMapper.to_record(entity, resource, opts)}

      {:error, {:http_error, status, body}} ->
        {:error, ErrorMapper.to_error(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
