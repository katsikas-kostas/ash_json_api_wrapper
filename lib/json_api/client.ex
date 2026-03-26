defmodule AshJsonApiWrapper.Client do
  @moduledoc """
  HTTP client wrapping Req for JSON API requests.

  Supports `Req.Test` plug-based stubs for testing. Stubs are automatically
  detected when registered via `Req.Test.stub/2` using the resource module
  as the stub name.
  """

  def get(url, resource) do
    [url: url, retry: false]
    |> put_test_plug(resource)
    |> Req.get()
    |> handle_response()
  end

  if Mix.env() == :test do
    defp put_test_plug(opts, resource) do
      Keyword.put(opts, :plug, {Req.Test, resource})
    end
  else
    defp put_test_plug(opts, _resource), do: opts
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, "HTTP #{status}: #{inspect(body)}"}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end
end
