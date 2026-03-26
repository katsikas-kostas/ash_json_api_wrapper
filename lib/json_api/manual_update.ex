defmodule AshJsonApiWrapper.JsonApi.ManualUpdate do
  @moduledoc """
  Implements `Ash.Resource.ManualUpdate` for JSON API-backed resources.
  """
  use Ash.Resource.ManualUpdate

  alias AshJsonApiWrapper.JsonApi.RecordMapper

  @impl true
  def update(changeset, opts, _context) do
    base_url = opts[:base_url]
    resource_path = opts[:resource_path]
    resource = changeset.resource
    id = changeset.data.id

    url = base_url <> resource_path <> "/#{id}"
    attrs = changeset.attributes

    case AshJsonApiWrapper.JsonApi.Client.patch(url, attrs, resource) do
      {:ok, body} ->
        {:ok, RecordMapper.to_record(body, resource)}

      {:error, {:http_error, status, body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
