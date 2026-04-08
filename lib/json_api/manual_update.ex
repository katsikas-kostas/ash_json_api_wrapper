defmodule AshJsonApiWrapper.JsonApi.ManualUpdate do
  @moduledoc """
  Implements `Ash.Resource.ManualUpdate` for JSON API-backed resources.
  """
  use Ash.Resource.ManualUpdate

  alias AshJsonApiWrapper.JsonApi.{ErrorMapper, ResponseMapper}

  @impl true
  def update(changeset, opts, _context) do
    base_url = opts[:base_url]
    resource_path = opts[:resource_path]
    resource = changeset.resource
    id = changeset.data.id

    url = base_url <> resource_path <> "/#{id}"
    attrs = changeset.attributes

    case AshJsonApiWrapper.JsonApi.Client.patch(url, attrs, resource, opts) do
      {:ok, body} ->
        if opts[:cache_ttl], do: AshJsonApiWrapper.JsonApi.Cache.flush(resource)
        entity = ResponseMapper.extract_entity(body, opts[:entity_path])
        {:ok, ResponseMapper.to_record(entity, resource, opts)}

      {:error, {:http_error, status, body}} ->
        {:error, ErrorMapper.to_error(status, body)}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
