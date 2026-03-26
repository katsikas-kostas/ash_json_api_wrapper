defmodule AshJsonApiWrapper.JsonApi.Client do
  @moduledoc """
  HTTP client wrapping Req for JSON API requests.

  In test environments, configure `Req.Test` stubs via application config:

      # config/test.exs
      config :ash_json_api_wrapper, req_test_plug: Req.Test

  Then register per-resource stubs in your tests:

      Req.Test.stub(MyResource, fn conn ->
        Req.Test.json(conn, %{"id" => "1", "name" => "Alice"})
      end)
  """

  def get(url, resource) do
    [url: url, retry: false]
    |> put_test_plug(resource)
    |> Req.get()
    |> handle_response()
  end

  def post(url, body, resource) do
    [url: url, retry: false, json: body]
    |> put_test_plug(resource)
    |> Req.post()
    |> handle_response()
  end

  def patch(url, body, resource) do
    [url: url, retry: false, json: body]
    |> put_test_plug(resource)
    |> Req.patch()
    |> handle_response()
  end

  def delete(url, resource) do
    [url: url, retry: false]
    |> put_test_plug(resource)
    |> Req.delete()
    |> handle_response()
    |> case do
      {:ok, _body} -> :ok
      error -> error
    end
  end

  defp put_test_plug(opts, resource) do
    case Application.get_env(:ash_json_api_wrapper, :req_test_plug) do
      nil -> opts
      plug_mod -> Keyword.put(opts, :plug, {plug_mod, resource})
    end
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}})
       when status in 200..299 do
    {:ok, body}
  end

  defp handle_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:http_error, status, body}}
  end

  defp handle_response({:error, reason}) do
    {:error, reason}
  end
end
