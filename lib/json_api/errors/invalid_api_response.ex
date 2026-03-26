defmodule AshJsonApiWrapper.JsonApi.Errors.InvalidApiResponse do
  @moduledoc false
  use Splode.Error, fields: [:status, :api_message], class: :invalid

  def message(%{status: status, api_message: msg}), do: "HTTP #{status}: #{msg}"
end
