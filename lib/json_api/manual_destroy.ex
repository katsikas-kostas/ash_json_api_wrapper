defmodule AshJsonApiWrapper.JsonApi.ManualDestroy do
  @moduledoc """
  Implements `Ash.Resource.ManualDestroy` for JSON API-backed resources.
  """
  use Ash.Resource.ManualDestroy

  @impl true
  def destroy(changeset, opts, _context) do
    base_url = opts[:base_url]
    resource_path = opts[:resource_path]
    resource = changeset.resource
    record = changeset.data
    id = record.id

    url = base_url <> resource_path <> "/#{id}"

    case AshJsonApiWrapper.JsonApi.Client.delete(url, resource) do
      :ok ->
        {:ok, record}

      {:error, {:http_error, status, body}} ->
        {:error, "HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
