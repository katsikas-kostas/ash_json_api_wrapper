defmodule AshJsonApiWrapper.ResponseMappingTest do
  use ExUnit.Case, async: true

  # --- Resource with entity_path ---

  defmodule WrappedUser do
    use Ash.Resource,
      domain: AshJsonApiWrapper.ResponseMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
      entity_path "data"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  # --- Resource with nested entity_path ---

  defmodule DeepWrappedUser do
    use Ash.Resource,
      domain: AshJsonApiWrapper.ResponseMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
      entity_path "response.data.items"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  # --- Resource with field path mapping ---

  defmodule MappedUser do
    use Ash.Resource,
      domain: AshJsonApiWrapper.ResponseMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"

      field :name, path: "profile.display_name"
    end

    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  # --- Resource with camelCase convention ---

  defmodule CamelUser do
    use Ash.Resource,
      domain: AshJsonApiWrapper.ResponseMappingTest.Domain,
      extensions: [AshJsonApiWrapper.JsonApi]

    json_api do
      base_url "https://api.example.com/v1"
      resource_path "/users"
      case_convention :camel_case
    end

    attributes do
      uuid_primary_key :id
      attribute :display_name, :string, public?: true
    end

    actions do
      defaults [:read]
    end
  end

  defmodule Domain do
    use Ash.Domain, validate_config_inclusion?: false

    resources do
      resource WrappedUser
      resource DeepWrappedUser
      resource MappedUser
      resource CamelUser
    end
  end

  describe "entity_path" do
    test "extracts list from top-level key" do
      id = Ash.UUID.generate()

      Req.Test.stub(WrappedUser, fn conn ->
        Req.Test.json(conn, %{"data" => [%{"id" => id, "name" => "Alice"}]})
      end)

      assert {:ok, [user]} = Ash.read(WrappedUser)
      assert user.id == id
      assert user.name == "Alice"
    end

    test "extracts single record from top-level key" do
      id = Ash.UUID.generate()

      Req.Test.stub(WrappedUser, fn conn ->
        Req.Test.json(conn, %{"data" => %{"id" => id, "name" => "Alice"}})
      end)

      assert {:ok, [user]} = Ash.read(WrappedUser)
      assert user.id == id
    end

    test "extracts list from deeply nested path" do
      id = Ash.UUID.generate()

      Req.Test.stub(DeepWrappedUser, fn conn ->
        Req.Test.json(conn, %{
          "response" => %{
            "data" => %{
              "items" => [%{"id" => id, "name" => "Alice"}]
            }
          }
        })
      end)

      assert {:ok, [user]} = Ash.read(DeepWrappedUser)
      assert user.id == id
    end
  end

  describe "field path mapping" do
    test "maps nested JSON path to Ash attribute" do
      id = Ash.UUID.generate()

      Req.Test.stub(MappedUser, fn conn ->
        Req.Test.json(conn, [%{"id" => id, "profile" => %{"display_name" => "Alice"}}])
      end)

      assert {:ok, [user]} = Ash.read(MappedUser)
      assert user.name == "Alice"
    end
  end

  describe "case_convention: :camel_case" do
    test "automatically converts camelCase keys to snake_case attributes" do
      id = Ash.UUID.generate()

      Req.Test.stub(CamelUser, fn conn ->
        Req.Test.json(conn, [%{"id" => id, "displayName" => "Alice"}])
      end)

      assert {:ok, [user]} = Ash.read(CamelUser)
      assert user.display_name == "Alice"
    end
  end

  describe "null values" do
    test "explicit null in API response sets attribute to nil (not skipped)" do
      id = Ash.UUID.generate()

      Req.Test.stub(WrappedUser, fn conn ->
        Req.Test.json(conn, %{"data" => [%{"id" => id, "name" => nil}]})
      end)

      assert {:ok, [user]} = Ash.read(WrappedUser)
      assert user.id == id
      assert user.name == nil
    end
  end
end
