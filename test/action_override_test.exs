defmodule AshJsonApiWrapper.ActionOverrideTest do
  use ExUnit.Case, async: true
  require Ash.Query

  defmodule UserResource do
    use Ash.Resource,
      domain: AshJsonApiWrapper.ActionOverrideTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"

      # Custom path for the search action
      action :search, path: "/users/search"

      # Custom method for search (POST instead of GET)
      action :search_post, path: "/users/search", method: :post

      # Path template with :id
      action :activate, path: "/users/:id/activate"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]

      read :search do
        argument :name, :string, allow_nil?: true
      end

      read :search_post do
        argument :name, :string, allow_nil?: true
      end

      read :activate do
      end
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource UserResource
    end
  end

  describe "path override" do
    test "uses overridden path instead of resource_path" do
      Req.Test.stub(UserResource, fn conn ->
        assert conn.request_path == "/v1/users/search"
        Req.Test.json(conn, [])
      end)

      UserResource
      |> Ash.Query.for_read(:search)
      |> Ash.read!()
    end
  end

  describe "method override" do
    test "sends POST instead of GET when method: :post" do
      Req.Test.stub(UserResource, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/users/search"
        Req.Test.json(conn, [])
      end)

      UserResource
      |> Ash.Query.for_read(:search_post)
      |> Ash.read!()
    end
  end

  describe "path template :id" do
    test "fills :id template from query id filter" do
      id = Ash.UUID.generate()

      Req.Test.stub(UserResource, fn conn ->
        assert conn.request_path == "/v1/users/#{id}/activate"
        Req.Test.json(conn, %{"id" => id, "name" => "Alice"})
      end)

      UserResource
      |> Ash.Query.for_read(:activate)
      |> Ash.Query.filter(id == ^id)
      |> Ash.read!()
    end
  end

  describe "default action uses resource_path" do
    test ":read action is not affected by overrides" do
      Req.Test.stub(UserResource, fn conn ->
        assert conn.request_path == "/v1/users"
        Req.Test.json(conn, [])
      end)

      Ash.read!(UserResource)
    end
  end
end
