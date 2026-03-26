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

  def get(url, resource, opts \\ []) do
    [url: url, retry: false]
    |> put_test_plug(resource)
    |> apply_auth(resource, opts[:auth])
    |> apply_before_hooks(opts[:before_request] || [])
    |> Req.get()
    |> handle_response()
    |> apply_after_hooks(opts[:after_response] || [])
  end

  def post(url, body, resource, opts \\ []) do
    [url: url, retry: false, json: body]
    |> put_test_plug(resource)
    |> apply_auth(resource, opts[:auth])
    |> apply_before_hooks(opts[:before_request] || [])
    |> Req.post()
    |> handle_response()
    |> apply_after_hooks(opts[:after_response] || [])
  end

  def patch(url, body, resource, opts \\ []) do
    [url: url, retry: false, json: body]
    |> put_test_plug(resource)
    |> apply_auth(resource, opts[:auth])
    |> apply_before_hooks(opts[:before_request] || [])
    |> Req.patch()
    |> handle_response()
    |> apply_after_hooks(opts[:after_response] || [])
  end

  def delete(url, resource, opts \\ []) do
    [url: url, retry: false]
    |> put_test_plug(resource)
    |> apply_auth(resource, opts[:auth])
    |> apply_before_hooks(opts[:before_request] || [])
    |> Req.delete()
    |> handle_response()
    |> case do
      {:ok, _body} -> :ok
      error -> error
    end
  end

  defp put_test_plug(req_opts, resource) do
    case Application.get_env(:ash_json_api_wrapper, :req_test_plug) do
      nil -> req_opts
      plug_mod -> Keyword.put(req_opts, :plug, {plug_mod, resource})
    end
  end

  defp apply_auth(req_opts, _resource, nil), do: req_opts

  defp apply_auth(req_opts, resource, auth_module) when is_atom(auth_module) do
    case auth_module.credentials(resource) do
      {:bearer, token} ->
        add_header(req_opts, "authorization", "Bearer #{token}")

      {:api_key, key, :header, header_name} ->
        add_header(req_opts, String.downcase(header_name), key)

      {:api_key, key, :query, param_name} ->
        url = req_opts[:url]
        separator = if String.contains?(url, "?"), do: "&", else: "?"
        Keyword.put(req_opts, :url, url <> separator <> "#{param_name}=#{key}")

      {:basic, username, password} ->
        encoded = Base.encode64("#{username}:#{password}")
        add_header(req_opts, "authorization", "Basic #{encoded}")

      :none ->
        req_opts
    end
  end

  defp add_header(req_opts, name, value) do
    Keyword.update(req_opts, :headers, [{name, value}], fn existing ->
      [{name, value} | existing]
    end)
  end

  defp apply_before_hooks(req_opts, []), do: req_opts

  defp apply_before_hooks(req_opts, hooks) do
    Enum.reduce(hooks, req_opts, fn
      {m, f, a}, opts -> apply(m, f, [opts | a])
      fun, opts when is_function(fun, 1) -> fun.(opts)
    end)
  end

  defp apply_after_hooks({:ok, body}, []), do: {:ok, body}
  defp apply_after_hooks({:error, _} = error, _hooks), do: error

  defp apply_after_hooks({:ok, body}, hooks) do
    result =
      Enum.reduce(hooks, body, fn
        {m, f, a}, b -> apply(m, f, [b | a])
        fun, b when is_function(fun, 1) -> fun.(b)
      end)

    {:ok, result}
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

  @doc false
  def map_error(status, body), do: AshJsonApiWrapper.JsonApi.ErrorMapper.to_error(status, body)
end
