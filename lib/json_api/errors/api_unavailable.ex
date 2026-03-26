defmodule AshJsonApiWrapper.JsonApi.Errors.ApiUnavailable do
  @moduledoc false
  use Splode.Error, fields: [:status, :api_message], class: :framework

  def message(%{status: status, api_message: msg}), do: "HTTP #{status}: #{msg}"
end
