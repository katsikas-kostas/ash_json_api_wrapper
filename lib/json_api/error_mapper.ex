defmodule AshJsonApiWrapper.JsonApi.ErrorMapper do
  @moduledoc """
  Maps HTTP error responses to Ash error structs.

  Status code mapping:
  - 400, 409, 422 → `Ash.Error.Invalid` (via `InvalidApiResponse`)
  - 401, 403       → `Ash.Error.Forbidden` (via `ForbiddenApiResponse`)
  - 429, 5xx       → `Ash.Error.Framework` (via `ApiUnavailable`)
  - other          → `Ash.Error.Invalid` (fallback)
  """

  alias AshJsonApiWrapper.JsonApi.Errors.{ApiUnavailable, ForbiddenApiResponse, InvalidApiResponse}

  @spec to_error(status :: integer(), body :: term()) :: Splode.Error.t()
  def to_error(status, body) do
    msg = extract_message(body)

    cond do
      status in [401, 403] ->
        ForbiddenApiResponse.exception(status: status, api_message: msg)

      status in [429] or status >= 500 ->
        ApiUnavailable.exception(status: status, api_message: msg)

      true ->
        InvalidApiResponse.exception(status: status, api_message: msg)
    end
  end

  defp extract_message(%{"error" => msg}) when is_binary(msg), do: msg
  defp extract_message(%{"message" => msg}) when is_binary(msg), do: msg
  defp extract_message(body) when is_binary(body), do: body
  defp extract_message(body), do: inspect(body)
end
