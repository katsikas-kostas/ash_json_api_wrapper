defmodule AshJsonApiWrapper.JsonApi.ManualCreate do
  @moduledoc """
  Implements `Ash.Resource.ManualCreate` for JSON API-backed resources.
  """
  use Ash.Resource.ManualCreate

  alias AshJsonApiWrapper.JsonApi.RecordMapper

  @impl true
  def create(changeset, opts, _context) do
    base_url = opts[:base_url]
    resource_path = opts[:resource_path]
    resource = changeset.resource

    url = base_url <> resource_path
    attrs = changeset.attributes

    case AshJsonApiWrapper.JsonApi.Client.post(url, attrs, resource) do
      {:ok, body} ->
        {:ok, RecordMapper.to_record(body, resource)}

      {:error, {:http_error, status, body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
