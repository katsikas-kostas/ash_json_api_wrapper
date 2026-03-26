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

      create :create do
        primary? true
        accept [:name]
      end

      update :update do
        primary? true
        accept [:name]
      end

      destroy :destroy do
        primary? true
      end
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

    test "no read actions raises compile error" do
      assert_raise Spark.Error.DslError, ~r/read action/, fn ->
        defmodule NoReadActionsResource do
          use Ash.Resource,
            domain: AshJsonApiWrapper.JsonApiTest.Domain,
            extensions: [AshJsonApiWrapper.JsonApi]

          json_api do
            base_url "https://api.example.com/v1"
            resource_path "/users"
          end

          attributes do
            uuid_primary_key :id
          end

          actions do
            defaults []
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

      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(User, Ash.UUID.generate())
    end
  end

  describe "create" do
    test "sends POST to base_url/resource_path with attributes and returns created record" do
      id = Ash.UUID.generate()

      Req.Test.stub(User, fn conn ->
        assert conn.request_path == "/v1/users"
        assert conn.method == "POST"
        {:ok, body, _conn} = Plug.Conn.read_body(conn)
        attrs = Jason.decode!(body)
        assert attrs["name"] == "Alice"

        Req.Test.json(conn, %{"id" => id, "name" => "Alice"})
      end)

      assert {:ok, user} = Ash.create(User, %{name: "Alice"})
      assert user.id == id
      assert user.name == "Alice"
    end

    test "non-2xx response returns an error" do
      Req.Test.stub(User, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(422, Jason.encode!(%{"error" => "Validation failed"}))
      end)

      assert {:error, %Ash.Error.Invalid{}} = Ash.create(User, %{name: "Alice"})
    end
  end

  describe "update" do
    test "sends PATCH to base_url/resource_path/:id with changed attributes" do
      id = Ash.UUID.generate()
      test_pid = self()

      Req.Test.stub(User, fn conn ->
        case conn.method do
          "GET" ->
            Req.Test.json(conn, %{"id" => id, "name" => "Alice"})

          "PATCH" ->
            send(test_pid, :patch_received)
            assert conn.request_path == "/v1/users/#{id}"
            {:ok, body, _conn} = Plug.Conn.read_body(conn)
            attrs = Jason.decode!(body)
            assert attrs["name"] == "Bob"

            Req.Test.json(conn, %{"id" => id, "name" => "Bob"})
        end
      end)

      {:ok, user} = Ash.get(User, id)
      assert {:ok, updated} = Ash.update(user, %{name: "Bob"})
      assert_received :patch_received
      assert updated.id == id
      assert updated.name == "Bob"
    end

    test "non-2xx response returns an error" do
      id = Ash.UUID.generate()

      Req.Test.stub(User, fn conn ->
        case conn.method do
          "GET" ->
            Req.Test.json(conn, %{"id" => id, "name" => "Alice"})

          "PATCH" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(422, Jason.encode!(%{"error" => "Validation failed"}))
        end
      end)

      {:ok, user} = Ash.get(User, id)
      assert {:error, %Ash.Error.Invalid{}} = Ash.update(user, %{name: "Bob"})
    end
  end

  describe "destroy" do
    test "sends DELETE to base_url/resource_path/:id and returns :ok" do
      id = Ash.UUID.generate()
      test_pid = self()

      Req.Test.stub(User, fn conn ->
        case conn.method do
          "GET" ->
            Req.Test.json(conn, %{"id" => id, "name" => "Alice"})

          "DELETE" ->
            send(test_pid, :delete_received)
            assert conn.request_path == "/v1/users/#{id}"
            Plug.Conn.send_resp(conn, 204, "")
        end
      end)

      {:ok, user} = Ash.get(User, id)
      assert :ok = Ash.destroy(user)
      assert_received :delete_received
    end

    test "200 response is treated as success" do
      id = Ash.UUID.generate()

      Req.Test.stub(User, fn conn ->
        case conn.method do
          "GET" ->
            Req.Test.json(conn, %{"id" => id, "name" => "Alice"})

          "DELETE" ->
            Req.Test.json(conn, %{"id" => id, "name" => "Alice"})
        end
      end)

      {:ok, user} = Ash.get(User, id)
      assert :ok = Ash.destroy(user)
    end

    test "non-2xx response returns an error" do
      id = Ash.UUID.generate()

      Req.Test.stub(User, fn conn ->
        case conn.method do
          "GET" ->
            Req.Test.json(conn, %{"id" => id, "name" => "Alice"})

          "DELETE" ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.send_resp(403, Jason.encode!(%{"error" => "Forbidden"}))
        end
      end)

      {:ok, user} = Ash.get(User, id)
      assert {:error, %Ash.Error.Invalid{}} = Ash.destroy(user)
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
