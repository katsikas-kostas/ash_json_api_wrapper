defmodule AshJsonApiWrapper.Testing do
  @moduledoc """
  Test helpers for `AshJsonApiWrapper.JsonApi`-backed resources.

  Wraps `Req.Test` to provide ergonomic per-resource response stubbing,
  so tests don't need to make real HTTP requests.

  ## Setup

  In `config/test.exs`:

      config :ash_json_api_wrapper, req_test_plug: Req.Test

  ## Usage

      defmodule MyApp.UserTest do
        use ExUnit.Case, async: true

        setup do
          AshJsonApiWrapper.Testing.stub_response(MyApp.User, [
            %{"id" => "1", "name" => "Alice"}
          ])
          :ok
        end

        test "reads users" do
          assert {:ok, [user]} = Ash.read(MyApp.User)
          assert user.name == "Alice"
        end

        test "handles 500 errors" do
          AshJsonApiWrapper.Testing.stub_error(MyApp.User, 500)
          assert {:error, %Ash.Error.Framework{}} = Ash.read(MyApp.User)
        end
      end
  """

  @doc """
  Stubs all HTTP requests for `resource` to return `body` as a JSON response with status 200.

  `body` can be a list (for collection responses) or a map (for single-record responses).
  """
  def stub_response(resource, body) do
    Req.Test.stub(resource, fn conn ->
      Req.Test.json(conn, body)
    end)
  end

  @doc """
  Stubs all HTTP requests for `resource` to return an error response with `status`.

  Optionally accepts a `message` string that will be included in the JSON body under `"error"`.
  """
  def stub_error(resource, status, message \\ "error") do
    Req.Test.stub(resource, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, Jason.encode!(%{"error" => message}))
    end)
  end
end
