defmodule AshJsonApiWrapper.JsonApiTest do
  use ExUnit.Case, async: true

  defmodule User do
    use Ash.Resource,
      domain: AshJsonApiWrapper.JsonApiTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    use Ash.Domain

    resources do
      resource User
    end
  end

  describe "get by ID" do
    test "sends GET to base_url/resource_path/id and returns a record" do
      id = Ash.UUID.generate()

      Req.Test.stub(User, fn conn ->
        assert conn.request_path == "/v1/users/#{id}"
        assert conn.method == "GET"
        Req.Test.json(conn, %{"id" => id, "name" => "Alice"})
      end)

      assert {:ok, user} = Ash.get(User, id)
      assert user.id == id
      assert user.name == "Alice"
    end
  end

  describe "DSL validation" do
    test "missing base_url raises compile error" do
      assert_raise Spark.Error.DslError, ~r/base_url/, fn ->
        defmodule InvalidResource do
          use Ash.Resource,
            domain: AshJsonApiWrapper.JsonApiTest.Domain,
            extensions: [AshJsonApiWrapper.JsonApi]

          json_api do
            resource_path "/users"
          end

          attributes do
            uuid_primary_key :id
          end

          actions do
            defaults [:read]
          end
        end
      end
    end

    test "missing resource_path raises compile error" do
      assert_raise Spark.Error.DslError, ~r/resource_path/, fn ->
        defmodule InvalidResource2 do
          use Ash.Resource,
            domain: AshJsonApiWrapper.JsonApiTest.Domain,
            extensions: [AshJsonApiWrapper.JsonApi]

          json_api do
            base_url "https://api.example.com"
          end

          attributes do
            uuid_primary_key :id
          end

          actions do
            defaults [:read]
          end
        end
      end
    end
  end

  describe "error handling" do
    test "non-200 response returns an error" do
      Req.Test.stub(User, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Ash.Error.Unknown{}} = Ash.read(User)
    end

    test "404 on get returns not found error" do
      Req.Test.stub(User, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(404, Jason.encode!(%{"error" => "Not Found"}))
      end)

      assert {:error, _} = Ash.get(User, Ash.UUID.generate())
    end
  end

  describe "list read" do
    test "sends GET to base_url/resource_path and returns records" do
      Req.Test.stub(User, fn conn ->
        assert conn.request_path == "/v1/users"
        assert conn.method == "GET"

        Req.Test.json(conn, [
          %{"id" => Ash.UUID.generate(), "name" => "Alice"},
          %{"id" => Ash.UUID.generate(), "name" => "Bob"}
        ])
      end)

      assert {:ok, users} = Ash.read(User)
      assert length(users) == 2
      assert Enum.map(users, & &1.name) |> Enum.sort() == ["Alice", "Bob"]
    end
  end
end
