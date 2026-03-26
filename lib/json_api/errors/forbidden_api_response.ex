defmodule AshJsonApiWrapper.JsonApi.Errors.ForbiddenApiResponse do
  @moduledoc false
  use Splode.Error, fields: [:status, :api_message], class: :forbidden

  def message(%{status: status, api_message: msg}), do: "HTTP #{status}: #{msg}"
end
