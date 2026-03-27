defmodule AshJsonApiWrapper.Paginator.OffsetLimit do
  @moduledoc """
  Built-in paginator that uses offset/limit query parameters.

  Sends `?offset=0&limit=<page_size>` on the first request, then
  increments offset by `page_size` on each subsequent page.
  Halts when the API returns fewer items than `page_size`.

  ## Options

  - `:page_size` — number of items per page (default: 25)
  - `:offset_param` — query param name for offset (default: `"offset"`)
  - `:limit_param` — query param name for limit (default: `"limit"`)

  ## Example

      json_api do
        paginator {AshJsonApiWrapper.Paginator.OffsetLimit, page_size: 50, offset_param: "skip", limit_param: "take"}
      end
  """
  use AshJsonApiWrapper.Paginator

  @impl true
  def start(opts) do
    page_size = Keyword.get(opts, :page_size, 25)
    offset_param = to_string(Keyword.get(opts, :offset_param, "offset"))
    limit_param = to_string(Keyword.get(opts, :limit_param, "limit"))

    {:ok, %{params: %{offset_param => 0, limit_param => page_size}}}
  end

  @impl true
  def continue(_response, entities, opts) do
    page_size = Keyword.get(opts, :page_size, 25)

    if length(entities) < page_size do
      :halt
    else
      next_offset = Keyword.get(opts, :accumulated_count, page_size)
      offset_param = to_string(Keyword.get(opts, :offset_param, "offset"))
      limit_param = to_string(Keyword.get(opts, :limit_param, "limit"))

      {:ok, %{params: %{offset_param => next_offset, limit_param => page_size}}}
    end
  end
end
